import Foundation
import CoreLocation

struct LifeguardStation: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    func distance(to location: CLLocation) -> CLLocationDistance {
        let stationLoc = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: stationLoc)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LifeguardStation, rhs: LifeguardStation) -> Bool {
        lhs.id == rhs.id
    }
}
