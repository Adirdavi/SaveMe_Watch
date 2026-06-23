import SwiftUI

struct HealthBubbleView: View {
    let swimmer: Swimmer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(swimmer.heartRate) bpm")
                    .font(.caption)
                    .bold()
            }
            HStack {
                Image(systemName: "lungs.fill")
                    .foregroundColor(.blue)
                Text("\(swimmer.spo2)%")
                    .font(.caption)
                    .bold()
            }
        }
        .padding(8)
        .background(Color(.systemBackground).opacity(0.85))
        .cornerRadius(10)
        .shadow(radius: 3)
    }
}
