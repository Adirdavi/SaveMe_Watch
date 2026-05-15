import Foundation
import Combine
import FirebaseDatabase
import CoreLocation

class FirebaseManager {
    static let shared = FirebaseManager()
    
    // For SwiftUI to consume easily, we use a CurrentValueSubject
    let swimmersPublisher = CurrentValueSubject<[String: Swimmer], Never>([:])
    
    private var dbRef: DatabaseReference!
    
    private init() {
        // In a real app, FirebaseApp.configure() would be called in the AppDelegate or App struct.
        // Assume it's already configured.
        dbRef = Database.database().reference()
    }
    
    func connect() {
        listenToLiveMonitor()
        listenToActiveWarnings()
    }
    
    private func listenToLiveMonitor() {
        dbRef.child("live_monitor").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var currentSwimmers = self.swimmersPublisher.value
            
            if !snapshot.exists() {
                // Handle case where all live monitors disappear, optional logic.
                return
            }
            
            guard let value = snapshot.value as? [String: Any] else { return }
            
            for (id, data) in value {
                guard let dict = data as? [String: Any] else { continue }
                
                var swimmer = currentSwimmers[id] ?? Swimmer(id: id)
                swimmer.heartRate = dict["heart_rate"] as? Int ?? swimmer.heartRate
                swimmer.spo2 = dict["spo2"] as? Int ?? swimmer.spo2
                swimmer.depthMeters = dict["depth_meters"] as? Double ?? swimmer.depthMeters
                swimmer.isSubmerged = dict["is_submerged"] as? Bool ?? swimmer.isSubmerged
                
                currentSwimmers[id] = swimmer
            }
            
            self.swimmersPublisher.send(currentSwimmers)
        }
    }
    
    private func listenToActiveWarnings() {
        dbRef.child("active_warnings").observe(.value) { [weak self] snapshot in
            guard let self = self else { return }
            var currentSwimmers = self.swimmersPublisher.value
            
            // If active_warnings is missing or empty, clear warnings for all swimmers
            if !snapshot.exists() {
                for (id, _) in currentSwimmers {
                    currentSwimmers[id]?.alertLevel = .none
                    currentSwimmers[id]?.alertReason = nil
                }
                self.swimmersPublisher.send(currentSwimmers)
                return
            }
            
            guard let value = snapshot.value as? [String: Any] else { return }
            
            // Clear warnings for swimmers not in the current snapshot
            for (id, _) in currentSwimmers {
                if value[id] == nil {
                    currentSwimmers[id]?.alertLevel = .none
                    currentSwimmers[id]?.alertReason = nil
                }
            }
            
            for (id, data) in value {
                guard let dict = data as? [String: Any] else { continue }
                
                var swimmer = currentSwimmers[id] ?? Swimmer(id: id)
                
                if let severityRaw = dict["severity"] as? String, let level = AlertLevel(rawValue: severityRaw) {
                    swimmer.alertLevel = level
                }
                
                swimmer.alertReason = dict["reason"] as? String
                
                if let lat = dict["latitude"] as? Double, let lon = dict["longitude"] as? Double {
                    swimmer.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                
                currentSwimmers[id] = swimmer
            }
            
            self.swimmersPublisher.send(currentSwimmers)
        }
    }
}
