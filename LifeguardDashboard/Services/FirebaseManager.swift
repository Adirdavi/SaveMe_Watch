import Foundation
import Combine
import FirebaseDatabase
import CoreLocation

class FirebaseManager {
    static let shared = FirebaseManager()
    
    let swimmersPublisher = CurrentValueSubject<[String: Swimmer], Never>([:])
    let stationsPublisher = CurrentValueSubject<[String: LifeguardStation], Never>([:])
    
    private var dbRef: DatabaseReference!
    
    private init() {
        dbRef = Database.database().reference()
    }
    
    func connect() {
        listenToAllDevices()
        listenToStations()
    }
    
    private func listenToAllDevices() {
        dbRef.child("devices").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            
            // אנחנו מאתחלים מילון ריק בכל עדכון.
            // ככה שעונים ישנים שלא ייכנסו אליו פשוט יימחקו אוטומטית מהמפה!
            var activeSwimmers: [String: Swimmer] = [:]
            
            if !snapshot.exists() {
                self.updateSwimmers([:])
                return
            }
            
            // הזמן הנוכחי בשניות (מולו נשווה)
            let currentTime = Date().timeIntervalSince1970
            
            for child in snapshot.children {
                guard let deviceSnapshot = child as? DataSnapshot else { continue }
                let deviceId = deviceSnapshot.key
                
                // --- 1. משיכת הנתונים מ-live_monitor ---
                let liveMonitorSnap = deviceSnapshot.childSnapshot(forPath: "live_monitor")
                
                guard let latestMonitor = liveMonitorSnap.children.allObjects.last as? DataSnapshot,
                      let dict = latestMonitor.value as? [String: Any] else {
                    continue // אם אין נתונים בכלל, דלג לשעון הבא
                }
                
                // --- בדיקת חותמת הזמן (Timestamp) ---
                var lastUpdate: TimeInterval = 0
                if let ts = dict["timestamp"] as? Double {
                    // הפיירבייס שלך שומר במילי-שניות (מספרים מעל 10 מיליארד).
                    // נחלק ב-1000 כדי להפוך לשניות סטנדרטיות של Swift.
                    lastUpdate = ts > 9999999999 ? ts / 1000 : ts
                }
                
                // 15 דקות = 900 שניות. נבדוק אם עבר יותר זמן מזה:
                if currentTime - lastUpdate > 900 {
                    print("⏳ Skipping Watch ID: \(deviceId) - Data is older than 15 minutes.")
                    continue // מדלגים על השעון - הוא לא ייכנס למפה!
                }
                
                // אם הגענו לכאן - השעון פעיל ורלוונטי
                var swimmer = Swimmer(id: deviceId)
                
                swimmer.heartRate = dict["heart_rate"] as? Int ?? swimmer.heartRate
                swimmer.spo2 = dict["spo2"] as? Int ?? swimmer.spo2
                swimmer.depthMeters = dict["depth_meters"] as? Double ?? swimmer.depthMeters
                swimmer.isSubmerged = dict["is_submerged"] as? Bool ?? swimmer.isSubmerged
                
                if let lat = dict["latitude"] as? Double,
                   let lon = dict["longitude"] as? Double {
                    swimmer.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                
                // --- 2. משיכת הנתונים מ-active_warnings ---
                let warningsSnap = deviceSnapshot.childSnapshot(forPath: "active_warnings")
                if let latestWarning = warningsSnap.children.allObjects.last as? DataSnapshot,
                   let warningDict = latestWarning.value as? [String: Any] {
                    
                    if let severityRaw = warningDict["severity"] as? String,
                       let level = AlertLevel(rawValue: severityRaw) {
                        swimmer.alertLevel = level
                    }
                    swimmer.alertReason = warningDict["reason"] as? String
                } else {
                    swimmer.alertLevel = .none
                    swimmer.alertReason = nil
                }
                
                // מוסיפים את השחיין הפעיל לרשימה החדשה
                activeSwimmers[deviceId] = swimmer
            }
            
            // מעדכנים את ה-UI רק עם השעונים שהיו פעילים ב-15 דקות האחרונות
            self.updateSwimmers(activeSwimmers)
        }
    }
    
    private func updateSwimmers(_ swimmers: [String: Swimmer]) {
        DispatchQueue.main.async {
            self.swimmersPublisher.send(swimmers)
        }
    }
    
    private func listenToStations() {
        dbRef.child("stations").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var activeStations: [String: LifeguardStation] = [:]
            
            if !snapshot.exists() {
                DispatchQueue.main.async {
                    self.stationsPublisher.send([:])
                }
                return
            }
            
            for child in snapshot.children {
                guard let stationSnapshot = child as? DataSnapshot else { continue }
                let stationId = stationSnapshot.key
                
                if let dict = stationSnapshot.value as? [String: Any],
                   let name = dict["name"] as? String,
                   let lat = dict["latitude"] as? Double,
                   let lon = dict["longitude"] as? Double {
                    let station = LifeguardStation(id: stationId, name: name, latitude: lat, longitude: lon)
                    activeStations[stationId] = station
                }
            }
            
            DispatchQueue.main.async {
                self.stationsPublisher.send(activeStations)
            }
        }
    }
    
    /// Clears the active warning from the database and archives its resolution category (e.g. Real or False alarm).
    func resolveAlert(deviceId: String, classification: String) {
        dbRef.child("devices").child(deviceId).child("active_warnings").removeValue()
        
        let resolutionData: [String: Any] = [
            "timestamp": ServerValue.timestamp(),
            "classification": classification
        ]
        dbRef.child("devices").child(deviceId).child("resolved_history").childByAutoId().setValue(resolutionData)
    }
}
