import SwiftUI

struct RootContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var isInitializing = true
    
    var body: some View {
        Group {
            if isInitializing {
                // Premium operational splash loading screen while restoring Keychain session
                ZStack {
                    LinearGradient(
                        colors: [Color(red: 0.04, green: 0.05, blue: 0.12), Color(red: 0.08, green: 0.12, blue: 0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 110, height: 110)
                            
                            Image(systemName: "lifepreserver.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                                .shadow(color: .blue.opacity(0.6), radius: 10)
                        }
                        
                        VStack(spacing: 8) {
                            Text("SAVEME")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .tracking(3)
                            
                            Text("Initializing Secure Channel...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    }
                }
            } else if appState.isAuthenticated {
                MainSplitView()
            } else {
                AuthView()
            }
        }
        .task {
            // Restore JWT session on app start
            await appState.restoreSession()
            
            // Short delay to ensure animations transition smoothly
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            withAnimation(.easeInOut(duration: 0.4)) {
                isInitializing = false
            }
        }
    }
}
