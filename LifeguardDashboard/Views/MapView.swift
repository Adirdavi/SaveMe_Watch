import SwiftUI
import MapKit

struct MapView: View {
    @ObservedObject var viewModel: SwimmerViewModel
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        ZStack(alignment: .top) {
            Map(position: $position) {
                ForEach(viewModel.sortedSwimmers) { swimmer in
                    if let coord = swimmer.coordinate {
                        Annotation(swimmer.id, coordinate: coord) {
                            SwimmerMarkerView(swimmer: swimmer)
                        }
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            
            // RED Alert Banner & Silence Button
            if viewModel.activeRedAlert {
                HStack {
                    Text("🚨 סכנת חיים - RED ALERT 🚨")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.silenceAlarm()
                    }) {
                        Text("Silence Alarm")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                    }
                    .padding()
                }
                .background(Color.red.opacity(0.9))
                .cornerRadius(12)
                .padding()
                .shadow(radius: 10)
            }
        }
        .onChange(of: viewModel.sortedSwimmers) { oldSwimmers, newSwimmers in
            // Auto-center map on first red alert swimmer if one just appeared
            let oldHasRed = oldSwimmers.contains { $0.alertLevel == .red }
            let newHasRed = newSwimmers.contains { $0.alertLevel == .red }
            
            if !oldHasRed && newHasRed {
                if let firstRed = newSwimmers.first(where: { $0.alertLevel == .red }),
                   let coord = firstRed.coordinate {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        position = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 100, longitudinalMeters: 100))
                    }
                }
            }
        }
    }
}

struct SwimmerMarkerView: View {
    let swimmer: Swimmer
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: 8) {
            HealthBubbleView(swimmer: swimmer)
            
            ZStack {
                if swimmer.alertLevel == .red {
                    Circle()
                        .fill(markerColor.opacity(0.4))
                        .frame(width: 60, height: 60)
                        .scaleEffect(isPulsing ? 1.5 : 0.5)
                        .opacity(isPulsing ? 0.0 : 1.0)
                }
                
                Circle()
                    .fill(markerColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2.5)
                    )
                    .shadow(color: swimmer.alertLevel == .yellow ? .yellow : .clear, radius: swimmer.alertLevel == .yellow ? 12 : 2)
            }
        }
        .onAppear {
            if swimmer.alertLevel == .red {
                withAnimation(Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }
    
    private var markerColor: Color {
        switch swimmer.alertLevel {
        case .red: return .red
        case .yellow: return .yellow
        case .none: return .blue
        }
    }
}
