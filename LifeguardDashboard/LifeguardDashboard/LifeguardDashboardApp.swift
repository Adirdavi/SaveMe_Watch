import SwiftUI
import FirebaseCore

@main
struct LifeguardDashboardApp: App {
    init() {
       
        FirebaseApp.configure()

        FirebaseManager.shared.connect()
    }
    
    var body: some Scene {
        WindowGroup {
            MainSplitView()
                .preferredColorScheme(.dark)
        }
    }
}
