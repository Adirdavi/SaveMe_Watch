//
//  TriageEngine.swift
//  saveme Watch App
//
//  Created by Adir Davidov on 22/04/2026.
//

import Foundation

struct TriageAlert {
    let severity: String // "RED" או "YELLOW"
    let reason: String
}

class TriageEngine {
    // --- נתוני בסיס לפי המסמך ---
    // ההנחה באבטיפוס היא שהמשתמש גבר מעל גיל 18, מעל מטר וחצי, ושוקל מעל 50 ק"ג
    private var baselineHR: Double = 120.0  // נורמה בשחייה לפי המסמך (110-140)
    private var baselineSpO2: Double = 98.0 // סטורציה נורמלית
    private var userHeightMeters: Double = 1.80 // גובה הצוללן במטרים (לצורך חישוב 0.6)

    // --- טיימרים למעקב זמנים (השהיה) ---
    private var hrAnomalyStartTime: Date? = nil
    private var spo2AnomalyStartTime: Date? = nil
    private var lastWarningTime: Date = Date.distantPast // למניעת הצפת פיירבייס

    func evaluate(currentHR: Double, currentSpO2: Double, currentDepth: Double) -> TriageAlert? {
        let now = Date()
        
        // חישוב סטיות בהתאם לחוקי המסמך
        let hrDeviation = abs(currentHR - baselineHR) / baselineHR
        let spo2Drop = baselineSpO2 - currentSpO2
        
        var triggeredRed = false
        var triggeredYellow = false
        var alertReason = ""

        // ==========================================
        // 🟥 דגלים אדומים (נבדק ראשון כי זה חירום קריטי)
        // ==========================================
        
        // 1. עומק: גובה האדם * 0.6
        if currentDepth > (userHeightMeters * 0.6) {
            triggeredRed = true
            alertReason = "RED_FLAG: חריגת עומק מסוכנת"
        }
        // 2. דופק: סטייה של 30% למשך 20 שניות
        else if hrDeviation >= 0.30 {
            if hrAnomalyStartTime == nil { hrAnomalyStartTime = now }
            else if now.timeIntervalSince(hrAnomalyStartTime!) >= 20 {
                triggeredRed = true
                alertReason = "RED_FLAG: סטיית דופק מעל 30% ל-20 שניות"
            }
        }
        // 3. חמצן בדם: מתחת 90% או צניחה של 2% ב-20 שניות (סכנת היפוקסיה)
        else if currentSpO2 < 90.0 {
            triggeredRed = true
            alertReason = "RED_FLAG: סטורציה קריטית מתחת 90%"
        } else if spo2Drop >= 2.0 {
            if spo2AnomalyStartTime == nil { spo2AnomalyStartTime = now }
            else if now.timeIntervalSince(spo2AnomalyStartTime!) >= 20 {
                triggeredRed = true
                alertReason = "RED_FLAG: צניחת חמצן מהירה - תחילת היפוקסיה"
            }
        }

        // ==========================================
        // 🟨 דגלים צהובים (אם אין דגל אדום)
        // ==========================================
        if !triggeredRed {
            // 1. דופק: סטייה של 15% למשך 20 שניות
            if hrDeviation >= 0.15 && hrDeviation < 0.30 {
                if hrAnomalyStartTime == nil { hrAnomalyStartTime = now }
                else if now.timeIntervalSince(hrAnomalyStartTime!) >= 20 {
                    triggeredYellow = true
                    alertReason = "YELLOW_FLAG: סטיית דופק מעל 15% ל-20 שניות"
                }
            }
            // 2. חמצן בדם: מתחת 94% או צניחה של 4% ב-30 שניות
            else if currentSpO2 < 94.0 {
                triggeredYellow = true
                alertReason = "YELLOW_FLAG: סטורציה נמוכה מתחת 94%"
            } else if spo2Drop >= 4.0 {
                if spo2AnomalyStartTime == nil { spo2AnomalyStartTime = now }
                else if now.timeIntervalSince(spo2AnomalyStartTime!) >= 30 {
                    triggeredYellow = true
                    alertReason = "YELLOW_FLAG: צניחת חמצן של 4% ב-30 שניות"
                }
            }
        }

        // --- איפוס טיימרים אם המצב התייצב (חזר לנורמה) ---
        if hrDeviation < 0.15 { hrAnomalyStartTime = nil }
        if currentSpO2 >= 94.0 && spo2Drop < 2.0 { spo2AnomalyStartTime = nil }

        // --- החזרת התראה (עם חסימה של 10 שניות בין התראות) ---
        if (triggeredRed || triggeredYellow) && now.timeIntervalSince(lastWarningTime) > 10 {
            lastWarningTime = now
            return TriageAlert(severity: triggeredRed ? "RED" : "YELLOW", reason: alertReason)
        }

        return nil // הכל תקין, אין התראה
    }
}
