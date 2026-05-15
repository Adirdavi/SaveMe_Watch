import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SwimmerViewModel
    
    var body: some View {
        List(viewModel.sortedSwimmers) { swimmer in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Swimmer \(swimmer.id.prefix(4))")
                        .font(.title3)
                        .bold()
                    Spacer()
                    if swimmer.alertLevel != .none {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(swimmer.alertLevel == .red ? .red : .yellow)
                            .font(.title2)
                    }
                }
                
                HStack {
                    Text("HR: \(swimmer.heartRate)")
                        .foregroundColor(swimmer.heartRate > 120 || swimmer.heartRate < 50 ? .red : .primary)
                    Spacer()
                    Text("SpO2: \(swimmer.spo2)%")
                        .foregroundColor(swimmer.spo2 < 95 ? .red : .primary)
                }
                .font(.subheadline)
                
                HStack {
                    Text("Depth: \(String(format: "%.1f", swimmer.depthMeters))m")
                    Spacer()
                    Text(swimmer.isSubmerged ? "Submerged" : "Surface")
                        .foregroundColor(swimmer.isSubmerged ? .blue : .secondary)
                }
                .font(.subheadline)
                
                if let reason = swimmer.alertReason, swimmer.alertLevel != .none {
                    Divider()
                    Text(reason)
                        .font(.callout)
                        .bold()
                        .foregroundColor(swimmer.alertLevel == .red ? .red : .yellow)
                        // Ensure Hebrew is correctly aligned from right to left
                        .environment(\.layoutDirection, .rightToLeft)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.vertical, 8)
            .listRowBackground(
                swimmer.alertLevel == .red ? Color.red.opacity(0.15) :
                swimmer.alertLevel == .yellow ? Color.yellow.opacity(0.15) :
                Color.clear
            )
        }
        .navigationTitle("Swimmers")
    }
}
