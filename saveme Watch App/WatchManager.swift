import Foundation
import SwiftUI
import Combine
import HealthKit
import CoreMotion
import Network

class WatchManager: NSObject, ObservableObject, CMWaterSubmersionManagerDelegate {

    // --- ניהול מצבי UI ---
    @Published var isSending: Bool = false
    @Published var alertMessage: String? = nil
    @Published var isOnline: Bool = true // נשמר רק לאינדיקציה ויזואלית
    
    // --- נתוני חיישנים ---
    @Published var heartRate: Double = 0
    @Published var currentDepth: Double = 0
    @Published var waterTemp: Double = 0
    @Published var isSubmerged: Bool = false
    @Published var isMonitoring: Bool = false
    
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.path.monitor")
    private let healthStore = HKHealthStore()
    private let submersionManager = CMWaterSubmersionManager()
    
    // --- Firebase REST URL ---
    private let databaseURL = "https://saveme-5666b-default-rtdb.europe-west1.firebasedatabase.app"
    
    override init() {
        super.init()

        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                // מעדכן את הסטטוס אבל לא חוסם לוגיקה
                self?.isOnline = (path.status == .satisfied)
                print("Network status: \(path.status)")
            }
        }
        pathMonitor.start(queue: pathQueue)
        
        if CMWaterSubmersionManager.waterSubmersionAvailable {
            submersionManager.delegate = self
        }
    }

    deinit {
        pathMonitor.cancel()
    }
    
    // --- פונקציית שליחה משופרת (ללא חסימת Offline) ---
    private func sendToRestAPI(endpoint: String, data: [String: Any], isManual: Bool = false) {
        guard let url = URL(string: "\(databaseURL)/\(endpoint).json") else { return }
        
        if isManual {
            DispatchQueue.main.async {
                self.isSending = true
                self.alertMessage = nil
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Timeout של 15 שניות כדי לתת ל-Wi-Fi של השעון זמן להתעורר
        request.timeoutInterval = 15
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            if isManual {
                DispatchQueue.main.async {
                    self.isSending = false
                    self.alertMessage = "שגיאה בעיבוד הנתונים"
                }
            }
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if isManual { self.isSending = false }
                
                if let error = error {
                    print("REST Error: \(error.localizedDescription)")
                    if isManual {
                        // אם יש שגיאה, נבדוק אם זה נראה כמו בעיית אינטרנט
                        self.alertMessage = "שגיאת תקשורת. וודא שה-Wi-Fi בשעון דלוק."
                    }
                } else if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        if isManual { self.alertMessage = "הנתונים נשמרו ב-Firebase!" }
                    } else {
                        if isManual { self.alertMessage = "שגיאת שרת: \(httpResponse.statusCode)" }
                    }
                }
            }
        }.resume()
    }

    // --- כפתור הפעלה ידני ---
    func manualUpload() {
        let testData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "heart_rate": self.heartRate > 0 ? self.heartRate : Double.random(in: 60...100),
            "depth": self.currentDepth,
            "is_online_at_send": self.isOnline, // לדיבג: נראה מה הקוד חשב באותו רגע
            "type": "Manual_Sync"
        ]
        sendToRestAPI(endpoint: "manual_uploads", data: testData, isManual: true)
    }

    // --- לוגיקה אוטומטית (נשארת ללא שינוי) ---
    func sendDataToFirebase() {
        let alertData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "heart_rate": self.heartRate,
            "depth_meters": self.currentDepth,
            "water_temp_celsius": self.waterTemp,
            "is_submerged": self.isSubmerged
        ]
        sendToRestAPI(endpoint: "live_monitor", data: alertData, isManual: false)
    }

    // --- HealthKit & Submersion Delegates ---
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async {
            self.isSubmerged = (event.state == .submerged)
            if event.state == .submerged {
                self.startHeartRateQuery()
                self.sendToRestAPI(endpoint: "emergency_alerts", data: ["status": "WATER_DETECTED"], isManual: false)
            }
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        DispatchQueue.main.async {
            if let depth = measurement.depth {
                self.currentDepth = depth.value
                self.sendDataToFirebase()
            }
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate temperature: CMWaterTemperature) {
        DispatchQueue.main.async { self.waterTemp = temperature.temperature.value }
    }
    
    func requestAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { success, _ in
            if success { self.startHeartRateQuery() }
        }
    }
    
    func startHeartRateQuery() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        DispatchQueue.main.async { self.isMonitoring = true }
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.processSamples(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in self.processSamples(samples) }
        healthStore.execute(query)
    }
    
    private func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        let hr = lastSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        DispatchQueue.main.async {
            self.heartRate = hr
            self.sendDataToFirebase()
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) { print(error.localizedDescription) }
}
