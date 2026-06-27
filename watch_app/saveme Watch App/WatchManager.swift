import Foundation
import SwiftUI
import Combine
import HealthKit
import CoreMotion
import WatchKit
import CoreLocation

class WatchManager: NSObject, ObservableObject, CMWaterSubmersionManagerDelegate, HKWorkoutSessionDelegate {

    @Published var isSending: Bool = false
    @Published var alertMessage: String? = nil
    @Published var isOnline: Bool = true
    
    @Published var heartRate: Double = 0
    @Published var currentSpO2: Double = 98.0
    @Published var currentDepth: Double = 0
    @Published var waterTemp: Double = 0
    @Published var isSubmerged: Bool = false
    @Published var isMonitoring: Bool = false
    @Published var currentLocation: CLLocationCoordinate2D?
    
    @Published var isDemoMode: Bool = false
    private var liveMonitorHistory: [String: Any] = [:]

    private let firebaseService = FirebaseService()
    private let locationService = LocationService()
    private let triageEngine = TriageEngine()
    
    private let healthStore = HKHealthStore()
    private let submersionManager = CMWaterSubmersionManager()
    
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private var lastSyncTime: Date = Date.distantPast
    
    private var hrQuery: HKQuery?
    private var spo2Query: HKQuery?
    
    override init() {
        super.init()

        firebaseService.onNetworkUpdate = { [weak self] onlineStatus in
            DispatchQueue.main.async { self?.isOnline = onlineStatus }
        }
        
        locationService.onLocationUpdate = { [weak self] coordinate in
            DispatchQueue.main.async {
                self?.currentLocation = coordinate
                self?.sendDataToFirebase()
            }
        }
        
        if CMWaterSubmersionManager.waterSubmersionAvailable {
            submersionManager.delegate = self
        }
    }
    

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
    
    func saveProfile(name: String, age: Int, height: Double, weight: Double, gender: String) {
        firebaseService.updateUserProfile(name: name, age: age, height: height, weight: weight, gender: gender)
    }

    func sendDataToFirebase() {
        let now = Date()
        guard now.timeIntervalSince(lastSyncTime) >= 5.0 else { return }
        lastSyncTime = now
        
        var effectiveHR = self.heartRate
        var effectiveSpO2 = self.currentSpO2
        var effectiveDepth = self.currentDepth
        var effectiveSubmerged = self.isSubmerged
        
        if isDemoMode {
            effectiveSubmerged = true
            // מחליף מצב כל 15 שניות בין צהוב לאדום
            let isYellowPhase = (Int(now.timeIntervalSince1970) / 15) % 2 == 0
            if isYellowPhase {
                effectiveHR = 145.0   // דגל צהוב
                effectiveSpO2 = 92.0  // דגל צהוב
                effectiveDepth = 0.5
            } else {
                effectiveHR = 160.0   // דגל אדום
                effectiveSpO2 = 85.0  // דגל אדום
                effectiveDepth = 5.0  // דגל אדום
            }
        }
        
        var alertData: [String: Any] = [
            "timestamp": now.timeIntervalSince1970 * 1000,
            "heart_rate": effectiveHR,
            "spo2": effectiveSpO2,
            "depth_meters": effectiveDepth,
            "water_temp_celsius": self.waterTemp,
            "is_submerged": effectiveSubmerged,
            "is_demo_mode": self.isDemoMode
        ]
        
        if let loc = currentLocation {
            alertData["latitude"] = loc.latitude
            alertData["longitude"] = loc.longitude
        }
        
        // --- 30-Second Rolling Window Logic ---
        let timestampStr = String(Int64(now.timeIntervalSince1970 * 1000))
        liveMonitorHistory[timestampStr] = alertData
        
        let thirtySecondsAgo = now.timeIntervalSince1970 * 1000 - 30000
        for key in liveMonitorHistory.keys {
            if let ts = Double(key), ts < thirtySecondsAgo {
                liveMonitorHistory.removeValue(forKey: key)
            }
        }
        
        sendData(endpoint: "live_monitor", data: liveMonitorHistory, isManual: false)
        
        let userAge = UserDefaults.standard.integer(forKey: "userAge")
        let actualAge = userAge == 0 ? 25 : userAge
        
        let userHeight = UserDefaults.standard.double(forKey: "userHeight")
        let actualHeight = userHeight == 0.0 ? 1.80 : userHeight

        let userWeight = UserDefaults.standard.double(forKey: "userWeight")
        let actualWeight = userWeight == 0.0 ? 75.0 : userWeight

        if let alert = triageEngine.evaluate(currentHR: effectiveHR, currentSpO2: effectiveSpO2, currentDepth: effectiveDepth, age: actualAge, height: actualHeight, weight: actualWeight, isSubmerged: effectiveSubmerged) {
            
            // משדר מיד למציל ללא עיכוב!
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
        }
    }

    func stopMonitoring() {
        DispatchQueue.main.async {
            self.isMonitoring = false
            self.heartRate = 0
            self.currentSpO2 = 0
        }
        
        locationService.stop()
        
        if let hrq = hrQuery {
            healthStore.stop(hrq)
            hrQuery = nil
        }
        if let spo2q = spo2Query {
            healthStore.stop(spo2q)
            spo2Query = nil
        }
        
        workoutSession?.end()
        workoutSession = nil
        workoutBuilder = nil
    }

    func requestAuthorization() {
        locationService.requestPermission()
        locationService.start()
        
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!
        let workoutType = HKObjectType.workoutType()
        
        healthStore.requestAuthorization(toShare: [workoutType], read: [heartRateType, oxygenType]) { success, _ in
            if success {
                self.startHeartRateQuery()
                self.startSpO2Query()
            }
        }
    }

    private func startBackgroundSession() {
        let config = HKWorkoutConfiguration()
        config.activityType = .other
        config.locationType = .outdoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            workoutSession?.delegate = self // --- רישום לזיהוי הלחיצה הכפולה ---
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { _, _ in }
            
            locationService.start()
        } catch {
        }
    }

    func manager(_ manager: CMWaterSubmersionManager, didUpdate event: CMWaterSubmersionEvent) {
        DispatchQueue.main.async {
            self.isSubmerged = (event.state == .submerged)
            
            self.lastSyncTime = Date.distantPast
            self.sendDataToFirebase()
            
            if event.state == .submerged {
                self.startBackgroundSession()
                self.startHeartRateQuery()
                self.startSpO2Query()
                self.sendData(endpoint: "events", data: ["status": "WATER_DETECTED"])
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
        DispatchQueue.main.async {
            self.waterTemp = temperature.temperature.value
        }
    }
    
    func manager(_ manager: CMWaterSubmersionManager, errorOccurred error: Error) {
    }

    func startHeartRateQuery() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }
        DispatchQueue.main.async { self.isMonitoring = true }
        let query = HKAnchoredObjectQuery(type: sampleType, predicate: nil, anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            self.processHRSamples(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in self.processHRSamples(samples) }
        healthStore.execute(query)
        self.hrQuery = query
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
        self.spo2Query = query
    }
    
    private func processSpO2Samples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let lastSample = samples.last else { return }
        let spo2 = lastSample.quantity.doubleValue(for: HKUnit.percent()) * 100.0
        DispatchQueue.main.async {
            self.currentSpO2 = spo2
            self.sendDataToFirebase()
        }
    }
    
    // --- HKWorkoutSessionDelegate Methods (זיהוי הלחיצה הכפולה) ---
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async {
            // זיהוי מעבר למצב השהיה (כתוצאה מלחיצה על שני הכפתורים)
            if toState == .paused {
                // חזרה מיידית לניטור כדי לא לאבד נתונים
                workoutSession.resume()
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}
