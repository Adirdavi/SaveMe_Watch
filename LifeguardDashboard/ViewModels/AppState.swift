import Foundation
import Combine
import FirebaseAuth
import FirebaseDatabase

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showAlert: Bool = false
    
    private var dbRef: DatabaseReference {
        Database.database().reference()
    }
    
    init() {
        print("DEBUG_BUNDLE_ID: Current app Bundle ID is -> \(Bundle.main.bundleIdentifier ?? "Unknown")")
    }
    
    /// Map username to simulated email format for Firebase Auth compatibility, or use directly if already an email.
    private func emailFor(username: String) -> String {
        let cleaned = username.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        
        if cleaned.contains("@") && cleaned.contains(".") {
            return cleaned
        }
        return "\(cleaned)@saveme-lifeguard.com"
    }
    
    /// Signs up a new lifeguard with their Username, Password, and Arbour Coordinates.
    func signUp(username: String, password: String, latitude: Double, longitude: Double, arbourName: String? = nil) async {
        print("DEBUG_BUNDLE_ID: Current app Bundle ID is -> \(Bundle.main.bundleIdentifier ?? "Unknown")")
        isLoading = true
        errorMessage = nil
        
        let email = emailFor(username: username)
        print("ℹ️ Attempting Firebase Sign Up with Email: \(email)")
        
        do {
            // 1. Create User in Firebase Auth
            let authResult = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = authResult.user.uid
            
            // 2. Save profile coordinates in Firebase Realtime Database
            var profileData: [String: Any] = [
                "username": username,
                "arbourLatitude": latitude,
                "arbourLongitude": longitude
            ]
            if let aName = arbourName {
                profileData["arbourName"] = aName
            }
            
            try await dbRef.child("users").child(uid).child("profile").setValue(profileData)
            
            // 3. Set local state
            self.currentUser = UserProfile(username: username, arbourLatitude: latitude, arbourLongitude: longitude, arbourName: arbourName)
            self.isAuthenticated = true
            print("✅ Sign Up succeeded for UID: \(uid)")
        } catch {
            print("❌ Firebase Sign Up Error: \(error.localizedDescription)")
            print("Detailed error details: \(error)")
            self.errorMessage = getReadableErrorMessage(error)
            self.showAlert = true
        }
        
        isLoading = false
    }
    
    /// Authenticates an existing lifeguard with their Username and Password.
    func signIn(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        let email = emailFor(username: username)
        print("ℹ️ Attempting Firebase Sign In with Email: \(email)")
        
        do {
            // 1. Sign in via Firebase Auth
            let authResult = try await Auth.auth().signIn(withEmail: email, password: password)
            let uid = authResult.user.uid
            
            // 2. Retrieve Profile from Firebase Database
            await fetchUserProfile(uid: uid)
            print("✅ Sign In succeeded for UID: \(uid)")
        } catch {
            print("❌ Firebase Sign In Error: \(error.localizedDescription)")
            print("Detailed error details: \(error)")
            self.errorMessage = getReadableErrorMessage(error)
            self.showAlert = true
        }
        
        isLoading = false
    }
    
    /// Clears the credentials and terminates the session.
    func logout() {
        do {
            try Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
            print("✅ User logged out successfully.")
        } catch {
            print("❌ Sign Out Error: \(error)")
            self.errorMessage = error.localizedDescription
            self.showAlert = true
        }
    }
    
    /// Re-authenticates the user automatically if a secure JWT is present in the Keychain on startup.
    func restoreSession() async {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        isLoading = true
        await fetchUserProfile(uid: user.uid)
        isLoading = false
    }
    
    /// Helper to fetch user profile data from Realtime Database
    private func fetchUserProfile(uid: String) async {
        do {
            let snapshot = try await dbRef.child("users").child(uid).child("profile").getData()
            guard snapshot.exists(), let dict = snapshot.value as? [String: Any] else {
                throw NSError(domain: "SaveMe", code: 404, userInfo: [NSLocalizedDescriptionKey: "Lifeguard profile not found in database."])
            }
            
            guard let username = dict["username"] as? String,
                  let lat = dict["arbourLatitude"] as? Double,
                  let lon = dict["arbourLongitude"] as? Double else {
                throw NSError(domain: "SaveMe", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid profile data format in database."])
            }
            
            let arbourName = dict["arbourName"] as? String
            
            self.currentUser = UserProfile(username: username, arbourLatitude: lat, arbourLongitude: lon, arbourName: arbourName)
            self.isAuthenticated = true
        } catch {
            print("❌ Fetch Profile Error for UID \(uid): \(error)")
            self.errorMessage = getReadableErrorMessage(error)
            self.showAlert = true
            try? Auth.auth().signOut()
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    /// Updates the user's profile information, handling email updates if username changes.
    func updateProfile(newUsername: String, newArbourName: String?, latitude: Double, longitude: Double) async throws {
        guard let user = Auth.auth().currentUser, let currentProfile = self.currentUser else {
            throw NSError(domain: "SaveMe", code: 401, userInfo: [NSLocalizedDescriptionKey: "No active session."])
        }
        
        let uid = user.uid
        var updatedProfile = currentProfile
        
        // 1. If username changed, update Firebase Auth Email
        if newUsername != currentProfile.username {
            let newEmail = emailFor(username: newUsername)
            try await user.updateEmail(to: newEmail)
            updatedProfile.username = newUsername
        }
        
        // 2. Update Database
        var profileData: [String: Any] = [
            "username": newUsername,
            "arbourLatitude": latitude,
            "arbourLongitude": longitude
        ]
        
        if let arbourName = newArbourName, !arbourName.isEmpty {
            profileData["arbourName"] = arbourName
            updatedProfile.arbourName = arbourName
        } else {
            updatedProfile.arbourName = nil
        }
        
        try await dbRef.child("users").child(uid).child("profile").setValue(profileData)
        updatedProfile.arbourLatitude = latitude
        updatedProfile.arbourLongitude = longitude
        
        self.currentUser = updatedProfile
    }
    
    /// Helper to extract the actual root cause error message from Firebase Auth's generic wrapper errors.
    private func getReadableErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        print("DEBUG_AUTH_ERROR: Domain = \(nsError.domain), Code = \(nsError.code)")
        print("DEBUG_AUTH_ERROR_USERINFO: \(nsError.userInfo)")
        
        // Firebase Auth often wraps the specific API error in the underlying error
        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            print("DEBUG_UNDERLYING_ERROR: \(underlyingError.localizedDescription)")
            print("DEBUG_UNDERLYING_ERROR_USERINFO: \(underlyingError.userInfo)")
            
            if let serverMessage = underlyingError.userInfo["NSLocalizedDescription"] as? String {
                return serverMessage
            }
            if let debugDescription = underlyingError.userInfo["NSDebugDescription"] as? String {
                return debugDescription
            }
            return underlyingError.localizedDescription
        }
        
        // FIRAuthErrorDomain common code check
        if nsError.domain == "FIRAuthErrorDomain" {
            switch nsError.code {
            case 17000: // AuthErrorCode.internalError
                return "Internal Firebase Error. This is usually caused by: 1) Email/Password Authentication provider being disabled in your Firebase Console, or 2) A network/connectivity issue."
            default:
                break
            }
        }
        
        return nsError.localizedDescription
    }
}
