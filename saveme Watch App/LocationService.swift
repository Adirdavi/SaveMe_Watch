//
//  LocationService.swift
//  saveme Watch App
//
//  Created by Adir Davidov on 22/04/2026.
//

import Foundation
import CoreLocation

class LocationService: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        // שימוש ברמת הדיוק הגבוהה ביותר (קריטי לחילוץ)
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // הגדרה קריטית לשעון: מאפשר ל-GPS להמשיך לעבוד גם כשהמסך נכבה / רץ ברקע
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func start() {
        // בודק מראש האם יש הרשאה, ורק אז מפעיל
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }

    // --- פונקציית הקסם שהייתה חסרה ---
    // אפל קוראת לפונקציה הזו אוטומטית ברגע שהסטטוס משתנה (למשל, כשהמשתמש לוחץ "אשר")
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("GPS: Permission Granted. Starting location updates.")
            manager.startUpdatingLocation()
        } else {
            print("GPS: Permission Denied or Not Determined.")
        }
    }

    // --- קבלת הנתונים בפועל ---
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate?(location.coordinate)
    }
    
    // פונקציה שעוזרת לנו לדבג - אם ה-GPS קורס, זה ידפיס לנו למה
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("GPS Error: \(error.localizedDescription)")
    }
}
