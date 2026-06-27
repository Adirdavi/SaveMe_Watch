import SwiftUI

struct SimulationConfigView: View {
    @ObservedObject var viewModel: SwimmerViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var swimmerCount: Int = 4
    @State private var alertLevels: [AlertLevel] = [.none, .none, .none, .none]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Sleek tactical dark background
                Color(red: 0.04, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Section 1: Swimmer Count Controller
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SIMULATION PARAMETERS")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .tracking(1.5)
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Swimmer Units Count")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Select total mock devices to simulate")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Stepper(value: $swimmerCount, in: 1...10) {
                                        Text("\(swimmerCount)")
                                            .font(.title3)
                                            .bold()
                                            .foregroundColor(.white)
                                            .frame(minWidth: 40)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(10)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            
                            // Section 2: Individual Watch Config List
                            VStack(alignment: .leading, spacing: 12) {
                                Text("MOCK WATCH STATUS CONFIGURATION")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.orange)
                                    .tracking(1.5)
                                    .padding(.horizontal)
                                
                                ForEach(0..<swimmerCount, id: \.self) { index in
                                    if index < alertLevels.count {
                                        HStack(spacing: 16) {
                                            HStack(spacing: 8) {
                                                Circle()
                                                    .fill(colorForAlertLevel(alertLevels[index]))
                                                    .frame(width: 10, height: 10)
                                                
                                                Text("Mock Swimmer SIM-\(index + 1)")
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Spacer()
                                            
                                            Picker("Status", selection: $alertLevels[index]) {
                                                Text("Normal").tag(AlertLevel.none)
                                                Text("Yellow Alert").tag(AlertLevel.yellow)
                                                Text("Red Alert").tag(AlertLevel.red)
                                            }
                                            .pickerStyle(.segmented)
                                            .frame(maxWidth: 240)
                                        }
                                        .padding(14)
                                        .background(Color.white.opacity(0.04))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(alertLevels[index] != .none ? colorForAlertLevel(alertLevels[index]).opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
                                        )
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Bottom Start Button Container
                    VStack(spacing: 12) {
                        Divider()
                            .background(Color.white.opacity(0.1))
                        
                        Button(action: startSimulation) {
                            HStack {
                                Image(systemName: "play.fill")
                                Text("Start Tactical Simulation")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(14)
                            .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                    }
                    .background(Color(red: 0.04, green: 0.05, blue: 0.12))
                }
            }
            .navigationTitle("Simulation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(red: 0.04, green: 0.05, blue: 0.12), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
            }
            .onChange(of: swimmerCount) { _, newCount in
                adjustAlertLevelsArray(to: newCount)
            }
        }
    }
    
    private func adjustAlertLevelsArray(to newCount: Int) {
        if newCount > alertLevels.count {
            alertLevels.append(contentsOf: Array(repeating: .none, count: newCount - alertLevels.count))
        } else if newCount < alertLevels.count {
            alertLevels.removeLast(alertLevels.count - newCount)
        }
    }
    
    private func colorForAlertLevel(_ level: AlertLevel) -> Color {
        switch level {
        case .none: return .green
        case .yellow: return .yellow
        case .red: return .red
        }
    }
    
    private func startSimulation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            viewModel.spawnMockSwimmers(withAlertLevels: alertLevels)
            viewModel.isSimulationModeEnabled = true
        }
        dismiss()
    }
}
