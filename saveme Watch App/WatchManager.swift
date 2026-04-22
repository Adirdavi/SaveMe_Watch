import Foundation
import SwiftUI
import Combine
import HealthKit
import CoreMotion
import WatchKit
import CoreLocation

class WatchManager: NSObject, ObservableObject, CMWaterSubmersionManagerDelegate {

    // --- ניהול מצבי UI ---
    @Published var isSending: Bool = false
    @Published var alertMessage: String? = nil
    @Published var isOnline: Bool = true
    
    // --- נתוני חיישנים ומיקום ---
    @Published var heartRate: Double = 0
    @Published var currentSpO2: Double = 98.0 // נתון חמצן בדם
    @Published var currentDepth: Double = 0
    @Published var waterTemp: Double = 0
    @Published var isSubmerged: Bool = false
    @Published var isMonitoring: Bool = false
    @Published var currentLocation: CLLocationCoordinate2D?
    
    // --- שירותים חיצוניים (Services) ---
    private let firebaseService = FirebaseService()
    private let locationService = LocationService()
    private let triageEngine = TriageEngine()
    
    private let healthStore = HKHealthStore()
    private let submersionManager = CMWaterSubmersionManager()
    
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var lastSyncTime: Date = Date.distantPast
    
    override init() {
        super.init()

        // חיבור קלוז'רים (Callbacks) מהשירותים אל ה-UI
        firebaseService.onNetworkUpdate = { [weak self] onlineStatus in
            DispatchQueue.main.async { self?.isOnline = onlineStatus }
        }
        
        locationService.onLocationUpdate = { [weak self] coordinate in
            DispatchQueue.main.async { self?.currentLocation = coordinate }
        }
        
        if CMWaterSubmersionManager.waterSubmersionAvailable {
            submersionManager.delegate = self
        }
    }
    
    // --- פונקציית מעטפת לשליחה (הוסר ה-private כדי לאפשר גישה מה-UI) ---
    func sendData(endpoint: String, data: [String: Any], isManual: Bool = false) {
        if isManual { DispatchQueue.main.async { self.isSending = true; self.alertMessage = nil } }
        
        firebaseService.send(endpoint: endpoint, data: data, isManual: isManual) { [weak self] success, message in
            if isManual {
                DispatchQueue.main.async {
                    self?.isSending = false
                    self?.alertMessage = message
                }
            }
        }
    }

    // --- עדכון שוטף לפיירבייס ---
    func sendDataToFirebase() {
        let now = Date()
        // מגביל שליחה רגילה לכל 5 שניות
        guard now.timeIntervalSince(lastSyncTime) >= 5.0 else { return }
        lastSyncTime = now
        
        var alertData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970 * 1000,
            "heart_rate": self.heartRate,
            "spo2": self.currentSpO2, // הוספת חמצן
            "depth_meters": self.currentDepth,
            "water_temp_celsius": self.waterTemp,
            "is_submerged": self.isSubmerged
        ]
        
        // הוספת מיקום אם קיים
        if let loc = currentLocation {
            alertData["latitude"] = loc.latitude
            alertData["longitude"] = loc.longitude
        }
        
        sendData(endpoint: "live_monitor", data: alertData, isManual: false)
        
        // --- בדיקת מערכת התראות דרך מנוע ה-Triage ---
        if let alert = triageEngine.evaluate(currentHR: self.heartRate, currentSpO2: self.currentSpO2, currentDepth: self.currentDepth) {
            var warningData: [String: Any] = [
                "timestamp": Date().timeIntervalSince1970 * 1000,
                "severity": alert.severity,
                "reason": alert.reason,
                "heart_rate": self.heartRate,
                "spo2": self.currentSpO2,
                "depth": self.currentDepth
            ]
            
            if let loc = currentLocation {
                warningData["latitude"] = loc.latitude
                warningData["longitude"] = loc.longitude
            }
            
            sendData(endpoint: "active_warnings", data: warningData, isManual: false)
            
            // רטט שונה לפי רמת סכנה
            if alert.severity == "RED" {
                WKInterfaceDevice.current().play(.failure) // רטט חזק לסכנת חיים
            } else {
                WKInterfaceDevice.current().play(.directionUp) // רטט קל לאזהרה
            }
        }
    }

    // --- HealthKit & Permissions ---
    func requestAuthorization() {
        locationService.requestPermission()
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let workoutType = HKObjectType.workoutType()
        
        healthStore.requestAuthorization(toShare: [workoutType], read: [heartRateType, oxygenType]) { success, _ in
            if success {
                self.startHeartRateQuery()
                self.startSpO2Query() // התחלת קריאת חמצן
            }
        }
    }

    // --- ניהול ריצה ברקע ו-GPS ---
    private func startBackgroundSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
            
            locationService.start() // הפעלת GPS
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
                self.startSpO2Query()
                self.sendData(endpoint: "events", data: ["status": "WATER_DETECTED"])
            } else {
                self.locationService.stop() // חוסך סוללה כשיצאו מהמים
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
    
    // --- שאילתות חיישנים (דופק וחמצן) ---
    func startHeartRateQuery() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        DispatchQueue.main.async { self.isMonitoring = true }
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.processHRSamples(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in self.processHRSamples(samples) }
        healthStore.execute(query)
    }
    
    private func processHRSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        let hr = lastSample.quantity.doubleValue(for: HKUnit(from: "count/min"))
        DispatchQueue.main.async {
            self.heartRate = hr
            self.sendDataToFirebase()
        }
    }
    
    func startSpO2Query() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else { return }
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.processSpO2Samples(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in self.processSpO2Samples(samples) }
        healthStore.execute(query)
    }
    
    private func processSpO2Samples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        // HealthKit מחזיר סטורציה כשבר עשרוני (למשל 0.98), נכפיל ב-100 כדי שיהיה באחוזים
        let spo2 = lastSample.quantity.doubleValue(for: HKUnit.percent()) * 100.0
        DispatchQueue.main.async {
            self.currentSpO2 = spo2
            self.sendDataToFirebase()
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) { print(error.localizedDescription) }
}
