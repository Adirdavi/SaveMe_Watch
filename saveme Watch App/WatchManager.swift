import Foundation
import SwiftUI
import Combine
import HealthKit
import CoreMotion
import Network
import WatchKit

class WatchManager: NSObject, ObservableObject, CMWaterSubmersionManagerDelegate {

    // --- ניהול מצבי UI ---
    @Published var isSending: Bool = false
    @Published var alertMessage: String? = nil
    @Published var isOnline: Bool = true
    
    // --- נתוני חיישנים ---
    @Published var heartRate: Double = 0
    @Published var currentDepth: Double = 0
    @Published var waterTemp: Double = 0
    @Published var isSubmerged: Bool = false
    @Published var isMonitoring: Bool = false
    
    // --- מזהה ייחודי של המכשיר להפרדה ב-Firebase ---
    private let deviceID = WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown_device"
    
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.path.monitor")
    private let healthStore = HKHealthStore()
    private let submersionManager = CMWaterSubmersionManager()
    
    // ניהול ריצה ברקע
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    private let databaseURL = "https://saveme-5666b-default-rtdb.europe-west1.firebasedatabase.app"
    
    // --- משתני עזר לניהול זמנים (טיימרים) ---
    private var lastWarningTime: Date = Date.distantPast
    private var lastSyncTime: Date = Date.distantPast // <--- השעון שסופר 5 שניות
    
    override init() {
        super.init()

        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = (path.status == .satisfied)
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
    
    // --- פונקציית שליחה מבוססת נתיב מכשיר ---
    private func sendToRestAPI(endpoint: String, data: [String: Any], isManual: Bool = false) {
        let fullPath = "devices/\(deviceID)/\(endpoint)"
        guard let url = URL(string: "\(databaseURL)/\(fullPath).json") else { return }
        
        if isManual {
            DispatchQueue.main.async {
                self.isSending = true
                self.alertMessage = nil
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            if isManual { DispatchQueue.main.async { self.isSending = false } }
            return
        }
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if isManual {
                    self.isSending = false
                    if error == nil {
                        self.alertMessage = "נשמר ב-Firebase תחת המכשיר שלך!"
                    } else {
                        self.alertMessage = "שגיאת תקשורת"
                    }
                }
            }
        }.resume()
    }

    func manualUpload() {
        let testData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "heart_rate": self.heartRate > 0 ? self.heartRate : Double.random(in: 60...100),
            "depth": self.currentDepth,
            "type": "Manual_Sync"
        ]
        sendToRestAPI(endpoint: "manual_uploads", data: testData, isManual: true)
    }

    // --- מערכת התראות (מטריצת מדדים) ---
    private func checkIfWarningNeeded() {
        var hasIssue = false
        var reason = ""

        if heartRate > 155 {
            hasIssue = true
            reason = "CRITICAL_HIGH_HR"
        } else if heartRate < 40 && heartRate > 0 {
            hasIssue = true
            reason = "CRITICAL_LOW_HR"
        } else if currentDepth > 40 {
            hasIssue = true
            reason = "DEPTH_EXCEEDED"
        }

        if hasIssue && Date().timeIntervalSince(lastWarningTime) > 10 {
            lastWarningTime = Date()
            
            let warningData: [String: Any] = [
                "timestamp": Date().timeIntervalSince1970 * 1000,
                "reason": reason,
                "heart_rate": heartRate,
                "depth": currentDepth
            ]
            
            sendToRestAPI(endpoint: "active_warnings", data: warningData, isManual: false)
            WKInterfaceDevice.current().play(.directionUp)
        }
    }

    // --- עדכון שוטף לפיירבייס כל 5 שניות ---
    func sendDataToFirebase() {
        let now = Date()
        
        // מוודא שעברו לפחות 5 שניות מאז הפעם האחרונה ששלחנו
        guard now.timeIntervalSince(lastSyncTime) >= 5.0 else { return }
        
        // אם עברו 5 שניות, מעדכנים את זמן השליחה ושולחים
        lastSyncTime = now
        
        let alertData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "heart_rate": self.heartRate,
            "depth_meters": self.currentDepth,
            "water_temp_celsius": self.waterTemp,
            "is_submerged": self.isSubmerged
        ]
        
        sendToRestAPI(endpoint: "live_monitor", data: alertData, isManual: false)
        checkIfWarningNeeded()
    }

    // --- ניהול ריצה ברקע (Workout) ---
    private func startBackgroundSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("Background session failed")
        }
    }

    // --- Submersion Delegates ---
    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async {
            self.isSubmerged = (event.state == .submerged)
            if event.state == .submerged {
                self.startBackgroundSession()
                self.startHeartRateQuery()
                self.sendToRestAPI(endpoint: "events", data: ["status": "WATER_DETECTED"])
            }
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate measurement: CMWaterSubmersionMeasurement) {
        DispatchQueue.main.async {
            if let depth = measurement.depth {
                self.currentDepth = depth.value
                self.sendDataToFirebase() // יסונן על ידי מנגנון ה-5 שניות
            }
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, didUpdate temperature: CMWaterTemperature) {
        DispatchQueue.main.async { self.waterTemp = temperature.temperature.value }
    }
    
    // --- HealthKit ---
    func requestAuthorization() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let workoutType = HKObjectType.workoutType()
        
        healthStore.requestAuthorization(toShare: [workoutType], read: [heartRateType]) { success, _ in
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
            self.sendDataToFirebase() // יסונן על ידי מנגנון ה-5 שניות
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) { print(error.localizedDescription) }
}
