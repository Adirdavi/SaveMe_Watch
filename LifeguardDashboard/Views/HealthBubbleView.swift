import SwiftUI

struct HealthBubbleView: View {
    let swimmer: Swimmer
    
    var body: some View {
        VStack(spacing: 4) {
            if swimmer.alertLevel == .red {
                Text("🚨 DROWNING")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(4)
                    .shadow(color: Color.red.opacity(0.4), radius: 4)
            } else if swimmer.alertLevel == .yellow {
                Text("⚠️ WARNING")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.black)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow)
                    .cornerRadius(4)
                    .shadow(color: Color.yellow.opacity(0.4), radius: 4)
            }
            
            HStack(spacing: 12) {
                // Heart Rate
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 11, weight: .bold))
                    Text("HR: \(swimmer.heartRate)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.2))
                
                // SpO2
                HStack(spacing: 4) {
                    Image(systemName: "lungs.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 11, weight: .bold))
                    Text("SpO2: \(swimmer.spo2)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Divider()
                    .frame(height: 12)
                    .background(Color.white.opacity(0.2))
                
                // Depth
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.to.line")
                        .foregroundColor(.teal)
                        .font(.system(size: 11, weight: .bold))
                    Text("Depth: \(String(format: "%.1f", swimmer.depthMeters))m")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(red: 0.08, green: 0.10, blue: 0.22).opacity(0.9))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    swimmer.alertLevel == .red ? Color.red : (swimmer.alertLevel == .yellow ? Color.yellow : Color.white.opacity(0.15)),
                    lineWidth: swimmer.alertLevel != .none ? 1.5 : 1
                )
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}
