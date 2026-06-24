import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SwimmerViewModel
    @Binding var isSidebarVisible: Bool
    @State private var position: MapCameraPosition = .automatic
    @State private var currentRegion: MKCoordinateRegion? = nil
    @State private var selectedSwimmer: Swimmer? = nil
    @State private var showResolutionDialog = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $position, interactionModes: .all) {
                UserAnnotation()
                
                ForEach(viewModel.sortedSwimmers) { swimmer in
                    if let coord = swimmer.coordinate {
                        Annotation(swimmer.id, coordinate: coord) {
                            SwimmerMarkerView(swimmer: swimmer)
                                .opacity(viewModel.isSwimmerMatchingFilter(swimmer) ? 1.0 : 0.2)
                        }
                    }
                }
                
                ForEach(viewModel.stations) { station in
                    Annotation(station.name, coordinate: station.coordinate) {
                        StationMarkerView(station: station, isSelected: viewModel.selectedStation == station) {
                            viewModel.selectedStation = station
                        }
                        .opacity(viewModel.activeFilter == nil ? 1.0 : 0.5)
                    }
                }
                
                if let user = appState.currentUser {
                    let arbourCoord = CLLocationCoordinate2D(latitude: user.arbourLatitude, longitude: user.arbourLongitude)
                    
                    // Custom Annotation representing the tower
                    Annotation("My Lifeguard Arbour", coordinate: arbourCoord) {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 44, height: 44)
                                .shadow(color: .red.opacity(0.8), radius: 6)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                            
                            Image(systemName: "house.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    
                    // Tactical jurisdiction zones extending forward into the sea (Westward)
                    ForEach(viewModel.tacticalZones) { zone in
                        MapPolygon(coordinates: zone.coordinates)
                            .foregroundStyle(zone.fillColor)
                            .stroke(zone.strokeColor, lineWidth: 1.5)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .onMapCameraChange { context in
                currentRegion = context.region
            }
            
            // Overlays Container
            VStack {
                HStack(alignment: .top) {
                    // Simulation Mode Toggle
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.isSimulationModeEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.isSimulationModeEnabled ? "antenna.radiowaves.left.and.right" : "waveform.badge.magnifyingglass")
                                .font(.system(size: 14, weight: .bold))
                            Text(viewModel.isSimulationModeEnabled ? "SIM ON" : "SIM")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(viewModel.isSimulationModeEnabled ? .white : .orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(viewModel.isSimulationModeEnabled ? Color.orange : Color.black.opacity(0.65))
                        .background(.ultraThinMaterial)
                        .cornerRadius(18)
                        .shadow(color: viewModel.isSimulationModeEnabled ? .orange.opacity(0.5) : .black.opacity(0.35), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Floating Sidebar Toggle Button
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isSidebarVisible.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isSidebarVisible ? "sidebar.right" : "sidebar.left")
                                .font(.system(size: 16, weight: .bold))
                            if !isSidebarVisible {
                                Text("Open Controls")
                                    .font(.system(size: 12, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, isSidebarVisible ? 12 : 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.65))
                        .background(.ultraThinMaterial)
                        .cornerRadius(22)
                        .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.top, 20)
                }
                
                // Simulation Action Panel
                if viewModel.isSimulationModeEnabled {
                    SimulationControlPanel(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 16)
                }
                
                // RED Alert Banner (overlay at top)
                if viewModel.activeRedAlert {
                    ViewThatFits(in: .horizontal) {
                        // Wide layout
                        HStack {
                            Text("🚨 סכנת חיים - RED ALERT 🚨")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                            
                            Spacer(minLength: 20)
                            
                            HStack(spacing: 12) {
                                alertButtons
                            }
                            .padding(.trailing, 8)
                        }
                        
                        // Narrow layout
                        VStack(spacing: 12) {
                            Text("🚨 סכנת חיים - RED ALERT 🚨")
                                .font(.headline)
                                .bold()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                            
                            HStack(spacing: 12) {
                                alertButtons
                            }
                        }
                        .padding()
                    }
                    .background(Color.red.opacity(0.95))
                    .cornerRadius(12)
                    .padding()
                    .shadow(radius: 10)
                }
                
                Spacer()
                
                // Bottom FAB Overlay
                HStack(alignment: .bottom) {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Zoom In
                        Button(action: zoomIn) {
                            Image(systemName: "plus")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.65))
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        
                        // Zoom Out
                        Button(action: zoomOut) {
                            Image(systemName: "minus")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.65))
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                        
                        // FAB Button
                        Button(action: {
                            if appState.currentUser != nil {
                                centerOnArbour()
                            } else if let userLoc = viewModel.locationManager.lastLocation?.coordinate {
                                withAnimation(.easeInOut(duration: 1.0)) {
                                    position = .region(MKCoordinateRegion(center: userLoc, latitudinalMeters: 250, longitudinalMeters: 250))
                                }
                            }
                        }) {
                            Image(systemName: "scope")
                                .font(.title3)
                                .bold()
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .blue.opacity(0.45), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onChange(of: viewModel.sortedSwimmers) { oldSwimmers, newSwimmers in
            // Auto-center map on first red alert swimmer if one just appeared
            let oldHasRed = oldSwimmers.contains { $0.flagStatus == .redFlag }
            let newHasRed = newSwimmers.contains { $0.flagStatus == .redFlag }
            
            if !oldHasRed && newHasRed {
                if let firstRed = newSwimmers.first(where: { $0.flagStatus == .redFlag }),
                   let coord = firstRed.coordinate {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        position = .region(MKCoordinateRegion(center: coord, latitudinalMeters: 100, longitudinalMeters: 100))
                    }
                }
            }
        }
        .onChange(of: viewModel.mapFocusCoordinate) { oldFocus, newFocus in
            if let focus = newFocus {
                withAnimation(.easeInOut(duration: 1.0)) {
                    position = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: focus.latitude, longitude: focus.longitude),
                        latitudinalMeters: 150,
                        longitudinalMeters: 150
                    ))
                }
            }
        }
        .onAppear {
            centerOnArbour()
        }
        .onChange(of: appState.currentUser) { oldUser, newUser in
            if newUser != nil {
                centerOnArbour()
            }
        }
        .confirmationDialog("Dismiss Alarm?", isPresented: $showResolutionDialog, titleVisibility: .visible) {
            Button("False Alarm (Miss Alert)") {
                if let swimmer = selectedSwimmer {
                    viewModel.resolveAlert(for: swimmer, classification: "FALSE_ALARM")
                }
            }
            Button("Real Emergency") {
                if let swimmer = selectedSwimmer {
                    viewModel.resolveAlert(for: swimmer, classification: "REAL_EMERGENCY")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please classify this warning before dismissing it.")
        }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        Button(action: {
            viewModel.silenceAlarm()
        }) {
            HStack {
                Image(systemName: "speaker.slash.fill")
                Text("Mute Alert")
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.6))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        
        Button(action: {
            if let swimmer = viewModel.sortedSwimmers.first(where: { $0.flagStatus == .redFlag }) {
                self.selectedSwimmer = swimmer
                self.showResolutionDialog = true
            }
        }) {
            HStack {
                Image(systemName: "xmark.shield.fill")
                Text("Cancel Alert")
            }
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.red)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    
    private func centerOnArbour() {
        if let user = appState.currentUser {
            let coord = CLLocationCoordinate2D(latitude: user.arbourLatitude, longitude: user.arbourLongitude)
            withAnimation(.easeInOut(duration: 1.2)) {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 250,
                    longitudinalMeters: 250
                ))
            }
        }
    }
    
    private func zoomIn() {
        if let region = currentRegion {
            let newSpan = MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 0.5,
                longitudeDelta: region.span.longitudeDelta * 0.5
            )
            let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
            withAnimation(.easeInOut(duration: 0.3)) {
                position = .region(newRegion)
            }
        }
    }
    
    private func zoomOut() {
        if let region = currentRegion {
            let newSpan = MKCoordinateSpan(
                latitudeDelta: min(region.span.latitudeDelta * 2.0, 150.0),
                longitudeDelta: min(region.span.longitudeDelta * 2.0, 150.0)
            )
            let newRegion = MKCoordinateRegion(center: region.center, span: newSpan)
            withAnimation(.easeInOut(duration: 0.3)) {
                position = .region(newRegion)
            }
        }
    }
}

struct SwimmerMarkerView: View {
    let swimmer: Swimmer
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 4) {
            HealthBubbleView(swimmer: swimmer)
            
            ZStack {
                if swimmer.alertLevel != .none {
                    // Pulsing Ring 1
                    Circle()
                        .stroke(alertColor, lineWidth: 3)
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 2.0 : 0.8)
                        .opacity(isPulsing ? 0.0 : 1.0)
                    
                    // Pulsing Ring 2 (slightly offset)
                    Circle()
                        .stroke(alertColor, lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                        .scaleEffect(isPulsing ? 1.5 : 0.8)
                        .opacity(isPulsing ? 0.0 : 0.8)
                    
                    // Alert Center Badge
                    Circle()
                        .fill(alertColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .foregroundColor(.white)
                                .font(.system(size: 11, weight: .bold))
                        )
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2.5)
                        )
                        .shadow(color: alertColor, radius: 8)
                } else {
                    // Default Zone-Based UI
                    Circle()
                        .fill(zoneColor)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle().stroke(Color.white, lineWidth: 2.5)
                        )
                        .shadow(color: zoneColor.opacity(0.5), radius: 4, x: 0, y: 2)
                }
            }
        }
        .onAppear {
            if swimmer.alertLevel != .none {
                withAnimation(Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
        .onChange(of: swimmer.alertLevel) { oldAlert, newAlert in
            if newAlert != .none {
                withAnimation(Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                isPulsing = false
            }
        }
    }
    
    private var alertColor: Color {
        switch swimmer.alertLevel {
        case .red: return .red
        case .yellow: return .yellow
        case .none: return .clear
        }
    }
    
    private var zoneColor: Color {
        switch swimmer.zone {
        case .beach: return .green
        case .shallows: return .yellow
        case .deepWater: return .red
        case .outOfBounds: return .gray
        }
    }
}

struct StationMarkerView: View {
    let station: LifeguardStation
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue : Color.green.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .shadow(color: isSelected ? .blue : .green, radius: isSelected ? 8 : 3)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                
                Image(systemName: "lifepreserver.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold))
            }
            .scaleEffect(isSelected ? 1.2 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            .onTapGesture {
                onTap()
            }
            
            Text(station.name)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)
                .shadow(radius: 2)
        }
    }
}

struct SimulationControlPanel: View {
    @ObservedObject var viewModel: SwimmerViewModel
    @State private var pulseGlow = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseGlow ? 1.4 : 1.0)
                    .opacity(pulseGlow ? 0.6 : 1.0)
                
                Text("TACTICAL SIMULATION")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(.orange)
                
                Spacer()
                
                Text("\(viewModel.mockSwimmers.count + viewModel.ghostSwimmers.count) units")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    viewModel.triggerSimulatedYellowAlert()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Yellow Alert")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.yellow)
                    .cornerRadius(10)
                    .shadow(color: .yellow.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    viewModel.triggerSimulatedRedAlert()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Red Alert")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(10)
                    .shadow(color: .red.opacity(0.4), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.75))
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}
