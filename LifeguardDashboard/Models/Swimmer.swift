import Foundation
import CoreLocation

enum AlertLevel: String, Codable {
    case red = "RED"
    case yellow = "YELLOW"
    case none = "NONE"
}

struct Swimmer: Identifiable, Equatable {
    let id: String
    var heartRate: Int = 0
    var spo2: Int = 0
    var depthMeters: Double = 0.0
    var isSubmerged: Bool = false
    
    // Warning Data
    var alertLevel: AlertLevel = .none
    var alertReason: String? = nil
    var coordinate: CLLocationCoordinate2D? = nil
    
    static func == (lhs: Swimmer, rhs: Swimmer) -> Bool {
        lhs.id == rhs.id
    }
}
