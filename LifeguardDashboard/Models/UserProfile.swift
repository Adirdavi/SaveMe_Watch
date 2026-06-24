import Foundation

struct UserProfile: Codable, Equatable {
    var username: String
    var arbourLatitude: Double
    var arbourLongitude: Double
    var arbourName: String?
}
