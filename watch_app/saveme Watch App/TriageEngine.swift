//
//  TriageEngine.swift
//  saveme Watch App
//

import Foundation

struct TriageAlert {
    let severity: String
    let reason: String
}

class TriageEngine {
    private var baselineHR: Double = 120.0
    private var baselineSpO2: Double = 98.0

    private var hr15StartTime: Date? = nil
    private var hr30StartTime: Date? = nil
    private var spo2Drop4StartTime: Date? = nil
    private var spo2Drop2StartTime: Date? = nil
    private var lastWarningTime: Date = Date.distantPast
    
    func evaluate(currentHR: Double, currentSpO2: Double, currentDepth: Double, age: Int, height: Double, weight: Double, isSubmerged: Bool) -> TriageAlert? {
        guard isSubmerged else {
            hr15StartTime = nil
            hr30StartTime = nil
            spo2Drop4StartTime = nil
            spo2Drop2StartTime = nil
            return nil
        }
        
        let now = Date()
        let depthLimit = height * 0.6
        let hrDeviation = abs(currentHR - baselineHR) / baselineHR
        let spo2Drop = baselineSpO2 - currentSpO2
        
        var triggeredRed = false
        var triggeredYellow = false
        var alertReason = ""
        
        // --- עדכון טיימרים לדופק ---
        if hrDeviation >= 0.30 {
            if hr30StartTime == nil { hr30StartTime = now }
        } else {
            hr30StartTime = nil
        }
        
        if hrDeviation >= 0.15 {
            if hr15StartTime == nil { hr15StartTime = now }
        } else {
            hr15StartTime = nil
        }
        
        // --- עדכון טיימרים לחמצן ---
        if spo2Drop >= 2.0 {
            if spo2Drop2StartTime == nil { spo2Drop2StartTime = now }
        } else {
            spo2Drop2StartTime = nil
        }
        
        if spo2Drop >= 4.0 {
            if spo2Drop4StartTime == nil { spo2Drop4StartTime = now }
        } else {
            spo2Drop4StartTime = nil
        }

        // --- בדיקת דגלים אדומים ---
        if currentDepth > depthLimit {
            triggeredRed = true
            alertReason = "RED_FLAG: Depth > 60% of height"
        } else if currentSpO2 < 90.0 {
            triggeredRed = true
            alertReason = "RED_FLAG: SpO2 < 90%"
        } else if let start = spo2Drop2StartTime, now.timeIntervalSince(start) >= 20 {
            triggeredRed = true
            alertReason = "RED_FLAG: SpO2 drop >= 2% in 20s (Hypoxia warning)"
        } else if let start = hr30StartTime, now.timeIntervalSince(start) >= 20 {
            triggeredRed = true
            alertReason = "RED_FLAG: HR deviation >= 30% for 20s"
        }

        // --- בדיקת דגלים צהובים (אם אין אדום) ---
        if !triggeredRed {
            if currentSpO2 < 94.0 {
                triggeredYellow = true
                alertReason = "YELLOW_FLAG: SpO2 < 94%"
            } else if let start = spo2Drop4StartTime, now.timeIntervalSince(start) >= 30 {
                triggeredYellow = true
                alertReason = "YELLOW_FLAG: SpO2 drop >= 4% for 30s"
            } else if let start = hr15StartTime, now.timeIntervalSince(start) >= 20 {
                triggeredYellow = true
                alertReason = "YELLOW_FLAG: HR deviation >= 15% for 20s"
            }
        }

        // שליחת התראה (מגבלה של 10 שניות בין התראות)
        if (triggeredRed || triggeredYellow) && now.timeIntervalSince(lastWarningTime) > 10 {
            lastWarningTime = now
            return TriageAlert(severity: triggeredRed ? "RED" : "YELLOW", reason: alertReason)
        }

        return nil
    }
}
