import SwiftUI
import FirebaseCore

@main
struct LifeguardDashboardApp: App {
    @StateObject private var appState = AppState()
    
    init() {
        FirebaseApp.configure()
        FirebaseManager.shared.connect()
    }
    
    var body: some Scene {
        WindowGroup {
            RootContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}
