import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SwimmerViewModel
    @ObservedObject var zoneBoundaryManager: ZoneBoundaryManager
    @Binding var isSidebarVisible: Bool
    @State private var position: MapCameraPosition = .automatic
    @State private var currentRegion: MKCoordinateRegion? = nil
    @State private var showSimulationConfig = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            MapReader { proxy in
                Map(position: $position, interactionModes: .all) {
                    UserAnnotation()
                    
                    ForEach(viewModel.sortedSwimmers) { swimmer in
                        if let coord = swimmer.coordinate {
                            Annotation(swimmer.id, coordinate: coord) {
                                SwimmerMarkerView(swimmer: swimmer, isSelected: viewModel.selectedSwimmerId == swimmer.id)
                                    .onTapGesture {
                                        // In edit mode, tapping swimmers is disabled
                                        guard !zoneBoundaryManager.isEditModeActive else { return }
                                        withAnimation(.spring()) {
                                            if viewModel.selectedSwimmerId == swimmer.id {
                                                viewModel.selectedSwimmerId = nil
                                            } else {
                                                viewModel.selectedSwimmerId = swimmer.id
                                            }
                                        }
                                    }
                                    .opacity(viewModel.isSwimmerMatchingFilter(swimmer) ? 1.0 : 0.2)
                            }
                        }
                    }
                    
                    ForEach(viewModel.stations) { station in
                        Annotation(station.name, coordinate: station.coordinate) {
                            StationMarkerView(station: station, isSelected: viewModel.selectedStation?.id == station.id) {
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
                    
                    // MARK: - Edit Mode: Live Polygons & Vertex Annotations
                    if zoneBoundaryManager.isEditModeActive {
                        // Render live editing polygons for each zone with ≥3 vertices
                        ForEach(EditableZone.allCases) { zone in
                            let vertices = zoneBoundaryManager.verticesFor(zone)
                            if vertices.count >= 3 {
                                MapPolygon(coordinates: vertices)
                                    .foregroundStyle(zone.fillColor)
                                    .stroke(zone.color, lineWidth: 2.0)
                            }
                        }
                        
                        // Render vertex dot annotations for all zones
                        ForEach(EditableZone.allCases) { zone in
                            let vertices = zoneBoundaryManager.verticesFor(zone)
                            ForEach(Array(vertices.enumerated()), id: \.offset) { index, vertex in
                                Annotation("\(zone.rawValue)-\(index)", coordinate: vertex) {
                                    ZStack {
                                        Circle()
                                            .fill(zone.color)
                                            .frame(width: 14, height: 14)
                                            .shadow(color: zone.color.opacity(0.8), radius: 4)
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 14, height: 14)
                                        // Show index number for clarity
                                        if vertices.count <= 12 {
                                            Text("\(index + 1)")
                                                .font(.system(size: 7, weight: .heavy))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .onMapCameraChange { context in
                    currentRegion = context.region
                }
                .onTapGesture { screenPoint in
                    // Only handle taps for zone editing when edit mode is active
                    guard zoneBoundaryManager.isEditModeActive else { return }
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            zoneBoundaryManager.addVertex(coordinate)
                        }
                    }
                }
            }
            
            // Overlays Container
            VStack {
                HStack(alignment: .top) {
                    HStack(spacing: 8) {
                        // Simulation Mode Toggle
                        Button(action: {
                            if viewModel.isSimulationModeEnabled {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewModel.isSimulationModeEnabled = false
                                }
                            } else {
                                showSimulationConfig = true
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
                        
                        // Edit Zones Toggle Button
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                zoneBoundaryManager.isEditModeActive.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: zoneBoundaryManager.isEditModeActive ? "pencil.slash" : "pentagon")
                                    .font(.system(size: 14, weight: .bold))
                                Text(zoneBoundaryManager.isEditModeActive ? "EXIT EDIT" : "Edit Zones")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(zoneBoundaryManager.isEditModeActive ? .white : .cyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(zoneBoundaryManager.isEditModeActive ? Color.cyan : Color.black.opacity(0.65))
                            .background(.ultraThinMaterial)
                            .cornerRadius(18)
                            .shadow(color: zoneBoundaryManager.isEditModeActive ? .cyan.opacity(0.5) : .black.opacity(0.35), radius: 5, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    }
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
                
                // Zone Edit Control Panel
                if zoneBoundaryManager.isEditModeActive {
                    ZoneEditControlPanel(zoneBoundaryManager: zoneBoundaryManager)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal, 16)
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
            
            // Prominent On-Screen Alert Popup Overlay for Red or Yellow Alerts
            if let dangerSwimmer = viewModel.sortedSwimmers.first(where: { $0.alertLevel != .none }) {
                AlertPopupOverlay(swimmer: dangerSwimmer, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showSimulationConfig) {
            SimulationConfigView(viewModel: viewModel)
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
    let isSelected: Bool
    @State private var isPulsing = false
    
    var body: some View {
        VStack(spacing: 4) {
            if isSelected || swimmer.alertLevel != .none {
                HealthBubbleView(swimmer: swimmer)
                    .transition(.scale.combined(with: .opacity))
            }
            
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
                                                Text("Yellow").tag(AlertLevel.yellow)
                                                Text("Red").tag(AlertLevel.red)
                                            }
                                            .pickerStyle(.segmented)
                                            .frame(maxWidth: 200)
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

// MARK: - Zone Edit Control Panel

struct ZoneEditControlPanel: View {
    @ObservedObject var zoneBoundaryManager: ZoneBoundaryManager
    @State private var pulseGlow = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseGlow ? 1.4 : 1.0)
                    .opacity(pulseGlow ? 0.6 : 1.0)
                
                Text("ZONE BOUNDARY EDITOR")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(.cyan)
                
                Spacer()
                
                Text("\(zoneBoundaryManager.activeVertexCount) vertices")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Instruction hint
            Text("Tap the map to place vertices for the selected zone")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Zone Picker (Segmented Control)
            HStack(spacing: 0) {
                ForEach(EditableZone.allCases) { zone in
                    let isActive = zoneBoundaryManager.activeEditingZone == zone
                    let vertCount = zoneBoundaryManager.verticesFor(zone).count
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            zoneBoundaryManager.activeEditingZone = zone
                        }
                    }) {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(zone.color)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: zone.color, radius: isActive ? 4 : 0)
                                
                                Text(zone.rawValue)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            
                            Text("\(vertCount) pts")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(isActive ? .white.opacity(0.8) : .white.opacity(0.4))
                        }
                        .foregroundColor(isActive ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? zone.color.opacity(0.35) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isActive ? zone.color.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Action Buttons
            HStack(spacing: 10) {
                // Undo Last Vertex
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        zoneBoundaryManager.undoLastVertex()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 12, weight: .bold))
                        Text("Undo")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(zoneBoundaryManager.activeVertexCount == 0)
                .opacity(zoneBoundaryManager.activeVertexCount == 0 ? 0.4 : 1.0)
                
                // Clear Active Zone
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        zoneBoundaryManager.clearActiveZone()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .bold))
                        Text("Clear Zone")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(zoneBoundaryManager.activeVertexCount == 0)
                .opacity(zoneBoundaryManager.activeVertexCount == 0 ? 0.4 : 1.0)
                
                // Save Boundaries
                Button(action: {
                    Task {
                        await zoneBoundaryManager.saveToFirebase()
                    }
                }) {
                    HStack(spacing: 5) {
                        if zoneBoundaryManager.isSaving {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text("Save")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.cyan.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(10)
                    .shadow(color: .cyan.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(zoneBoundaryManager.isSaving)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.75))
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}
