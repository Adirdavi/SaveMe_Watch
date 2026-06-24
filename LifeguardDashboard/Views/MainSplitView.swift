import SwiftUI

struct MainSplitView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SwimmerViewModel()
    @State private var isSidebarVisible = true
    
    var body: some View {
        HStack(spacing: 0) {
            // Map on the Left
            MapView(viewModel: viewModel, isSidebarVisible: $isSidebarVisible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if isSidebarVisible {
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Alerts list on the Right
                SidebarView(viewModel: viewModel)
                    .frame(width: 380)
                    .background(Color(UIColor.systemBackground))
                    .transition(.move(edge: .trailing))
            }
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .onAppear {
            viewModel.currentUser = appState.currentUser
        }
        .onChange(of: appState.currentUser) { _, newUser in
            viewModel.currentUser = newUser
        }
    }
}
