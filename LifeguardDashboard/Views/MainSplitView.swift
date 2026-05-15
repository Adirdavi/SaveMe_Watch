import SwiftUI

struct MainSplitView: View {
    @StateObject private var viewModel = SwimmerViewModel()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            MapView(viewModel: viewModel)
                .ignoresSafeArea(.all, edges: .bottom)
        }
        .onAppear {
            FirebaseManager.shared.connect()
        }
    }
}
