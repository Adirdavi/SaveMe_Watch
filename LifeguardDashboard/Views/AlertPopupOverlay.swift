import SwiftUI
import MapKit

struct AlertPopupOverlay: View {
    let swimmer: Swimmer
    @ObservedObject var viewModel: SwimmerViewModel
    @State private var pulseGlow = false
    @State private var flashBorder = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                // Floating Alert Card on the bottom-left of the Map
                VStack(spacing: 14) {
                    // Header with emergency beacon
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(alertColor.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .scaleEffect(pulseGlow ? 1.3 : 1.0)
                            
                            Circle()
                                .fill(alertColor)
                                .frame(width: 32, height: 32)
                                .shadow(color: alertColor, radius: 8)
                            
                            Image(systemName: swimmer.alertLevel == .red ? "exclamationmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(swimmer.alertLevel == .red ? "🚨 DROWNING EMERGENCY" : "⚠️ TACTICAL WARNING")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(alertColor)
                            
                            Text("Swimmer \(swimmer.id.prefix(6)) in Danger")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Locate button
                        Button(action: {
                            if let coord = swimmer.coordinate {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    viewModel.selectedSwimmerId = swimmer.id
                                    viewModel.mapFocusCoordinate = FocusCoordinate(latitude: coord.latitude, longitude: coord.longitude)
                                }
                            }
                        }) {
                            Image(systemName: "location.magnifyingglass")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .bold))
                                .padding(10)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: Color.blue.opacity(0.4), radius: 4)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Details Row
                    HStack(spacing: 12) {
                        vitalItem(label: "HR", value: "\(swimmer.heartRate)", sub: "bpm", icon: "heart.fill", color: .red)
                        vitalItem(label: "SpO2", value: "\(swimmer.spo2)", sub: "%", icon: "lungs.fill", color: .blue)
                        vitalItem(label: "Depth", value: String(format: "%.1f", swimmer.depthMeters), sub: "m", icon: "arrow.down.to.line", color: .teal)
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    
                    if let reason = swimmer.alertReason {
                        HStack(alignment: .top, spacing: 4) {
                            Text("Reason:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                            Text(reason)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            withAnimation(.spring()) {
                                viewModel.resolveAlert(for: swimmer, classification: "FALSE_ALARM")
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "bell.slash.fill")
                                    .font(.system(size: 12))
                                Text("False Alarm")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                viewModel.resolveAlert(for: swimmer, classification: "REAL_EMERGENCY")
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lifepreserver.fill")
                                    .font(.system(size: 12))
                                Text(swimmer.alertLevel == .red ? "Dispatch Rescue" : "True Alarm")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(alertColor)
                            .cornerRadius(8)
                            .shadow(color: alertColor.opacity(0.4), radius: 6, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(width: 360)
                .background(Color(red: 0.04, green: 0.05, blue: 0.12).opacity(0.92))
                .background(.ultraThinMaterial)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(alertColor.opacity(flashBorder ? 0.95 : 0.25), lineWidth: 2)
                )
                .shadow(color: alertColor.opacity(0.25), radius: 15, x: 0, y: 4)
                .padding(.leading, 24)
                .padding(.bottom, 24)
                
                Spacer()
            }
        }
        .allowsHitTesting(true)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
            withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                flashBorder = true
            }
        }
    }
    
    private var alertColor: Color {
        swimmer.alertLevel == .red ? .red : .yellow
    }
    
    @ViewBuilder
    private func vitalItem(label: String, value: String, sub: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(value)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(sub)
                        .font(.system(size: 9))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
