import Foundation
import SwiftUI
import Combine
import HealthKit
import CoreMotion
import Network

// שימוש ב-REST API בלבד למניעת קריסות ב-watchOS
class WatchManager: NSObject, ObservableObject, CMWaterSubmersionManagerDelegate {

    // --- בדיקת חיבור אינטרנט ---
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.path.monitor")
    @Published private(set) var isOnline: Bool = true
    
    private let healthStore = HKHealthStore()
    private let submersionManager = CMWaterSubmersionManager()
    
    // --- כתובת Firebase REST API ---
    private let databaseURL = "https://saveme-5666b-default-rtdb.europe-west1.firebasedatabase.app"
    
    @Published var heartRate: Double = 0
    @Published var currentDepth: Double = 0
    @Published var waterTemp: Double = 0
    @Published var isSubmerged: Bool = false
    @Published var isMonitoring: Bool = false
    
    override init() {
        super.init()

        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = (path.status == .satisfied)
            }
        }
        pathMonitor.start(queue: pathQueue)
        
        // אתחול חיישן המים אם זמין במכשיר
        if CMWaterSubmersionManager.waterSubmersionAvailable {
            submersionManager.delegate = self
        }
    }

    deinit {
        pathMonitor.cancel()
    }
    
    // --- פונקציית שליחה לענן (REST) ---
    private func sendToRestAPI(endpoint: String, data: [String: Any]) {
        guard isOnline else {
            print("No internet — skipping REST API request")
            return
        }
        guard let url = URL(string: "\(databaseURL)/\(endpoint).json") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            print("JSON Error: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("REST Error: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("Success! Data sent to \(endpoint)")
            }
        }.resume()
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async {
            self.isSubmerged = (event.state == .submerged)
            
            // ברגע זיהוי מים - "מעירים" את המערכת
            if event.state == .submerged {
                print("Emergency: Water detected! Auto-starting monitoring...")
                
                // 1. הפעלת קריאת דופק אוטומטית
                self.startHeartRateQuery()
                
                // 2. שליחת התראה מיידית לנתיב חירום
                let emergencyData: [String: Any] = [
                    "status": "WATER_ENTRY_DETECTED",
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ]
                self.sendToRestAPI(endpoint: "emergency_alerts", data: emergencyData)
            }
        }
    }
    
    // --- עדכון עומק וטמפרטורה ---
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        DispatchQueue.main.async {
            if let depth = measurement.depth {
                self.currentDepth = depth.value
                self.sendDataToFirebase() // עדכון בזמן אמת על עומק הצלילה
            }
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate temperature: CMWaterTemperature) {
        DispatchQueue.main.async {
            self.waterTemp = temperature.temperature.value
        }
    }
    
    func requestAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let typesToRead: Set = [heartRateType]
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            if success { self.startHeartRateQuery() }
        }
    }
    
    func startHeartRateQuery() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        DispatchQueue.main.async { self.isMonitoring = true }

        let query = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.processSamples(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in
            self.processSamples(samples)
        }
        healthStore.execute(query)
    }
    
    private func processSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        let newHeartRate = lastSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        
        DispatchQueue.main.async {
            self.heartRate = newHeartRate
            self.sendDataToFirebase()
        }
    }
    
    func sendDataToFirebase() {
        let alertData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "heart_rate": self.heartRate,
            "depth_meters": self.currentDepth,
            "water_temp_celsius": self.waterTemp,
            "is_submerged": self.isSubmerged
        ]
        sendToRestAPI(endpoint: "live_monitor", data: alertData)
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) {
        print("Submersion Error: \(error.localizedDescription)")
    }
    
    func sendTestMessage() {
        let testData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "message": "Manual Test",
            "heart_rate": Int.random(in: 60...100)
        ]
        sendToRestAPI(endpoint: "test_connection", data: testData)
    }
}
