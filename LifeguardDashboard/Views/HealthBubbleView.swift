import SwiftUI

struct HealthBubbleView: View {
    let swimmer: Swimmer
    
    var body: some View {
        HStack(spacing: 8) {
            // Heart Rate
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 10, weight: .bold))
                Text("\(swimmer.heartRate)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Divider()
                .frame(height: 12)
            
            // SpO2
            HStack(spacing: 3) {
                Image(systemName: "lungs.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 10, weight: .bold))
                Text("\(swimmer.spo2)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Divider()
                .frame(height: 12)
            
            // Depth
            HStack(spacing: 3) {
                Image(systemName: "arrow.down.to.line")
                    .foregroundColor(.teal)
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.1fm", swimmer.depthMeters))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.systemBackground).opacity(0.85))
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    swimmer.alertLevel == .red ? Color.red : (swimmer.alertLevel == .yellow ? Color.yellow : Color.clear),
                    lineWidth: swimmer.alertLevel != .none ? 1.5 : 0
                )
        )
    }
}
