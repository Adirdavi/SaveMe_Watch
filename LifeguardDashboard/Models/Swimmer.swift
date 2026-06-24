import Foundation
import CoreLocation

enum AlertLevel: String, Codable {
    case red = "RED"
    case yellow = "YELLOW"
    case none = "NONE"
}

enum OperationalZone: String, Codable {
    case beach = "Beach"
    case shallows = "Shallows"
    case deepWater = "Deep Water"
    case outOfBounds = "Out of Bounds"
}

enum SwimmerFlagStatus {
    case outOfWater
    case greenFlag
    case yellowFlag
    case redFlag
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
    var zone: OperationalZone = .outOfBounds
    
    var flagStatus: SwimmerFlagStatus {
        if !isSubmerged {
            return .outOfWater
        }
        switch alertLevel {
        case .red: return .redFlag
        case .yellow: return .yellowFlag
        case .none: return .greenFlag
        }
    }
    
    static func == (lhs: Swimmer, rhs: Swimmer) -> Bool {
        lhs.id == rhs.id
    }
}
