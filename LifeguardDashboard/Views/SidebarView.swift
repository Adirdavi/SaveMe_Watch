import SwiftUI
import CoreLocation

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: SwimmerViewModel
    
    @State private var showEditProfile = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // User Session Header
                if let user = appState.currentUser {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ACTIVE OPERATOR")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text(user.username)
                                .font(.headline)
                                .foregroundColor(.primary)
                            if let arbour = user.arbourName, !arbour.isEmpty {
                                Text(arbour)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                showEditProfile = true
                            }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                withAnimation {
                                    appState.logout()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                                        .font(.footnote)
                                    Text("Sign Out")
                                        .font(.footnote)
                                        .bold()
                                }
                                .foregroundColor(.red)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .sheet(isPresented: $showEditProfile) {
                        EditProfileView()
                            .environmentObject(appState)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.2))
                        .padding(.horizontal)
                }

                // Section: Operational Zones Grouping (replacing Health Alerts)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Zones")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        // 1. Deep Water Zone (Red indicator)
                        zoneSection(title: "Deep Water Zone", zone: .deepWater)
                        
                        // 2. Shallows Zone (Yellow indicator)
                        zoneSection(title: "Shallows Zone", zone: .shallows)
                        
                        // 3. Beach Zone (Green indicator)
                        zoneSection(title: "Beach Zone", zone: .beach)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    @ViewBuilder
    private func zoneSection(title: String, zone: OperationalZone) -> some View {
        let filterType = filterTypeForZone(zone)
        let swimmers = viewModel.sortedSwimmers.filter { $0.zone == zone }
        let isSelected = viewModel.activeFilter == filterType
        
        VStack(alignment: .leading, spacing: 8) {
            ZoneHeaderCard(
                title: title,
                zone: zone,
                count: swimmers.count,
                isSelected: isSelected
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    if viewModel.activeFilter == filterType {
                        viewModel.activeFilter = nil
                    } else {
                        viewModel.activeFilter = filterType
                    }
                }
            }
            
            if viewModel.activeFilter == nil || isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    if swimmers.isEmpty {
                        Text("No swimmers in this zone")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(swimmers) { swimmer in
                            SwimmerRowView(swimmer: swimmer, viewModel: viewModel)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.vertical, 4)
            }
        }
    }
    
    private func filterTypeForZone(_ zone: OperationalZone) -> SwimmerFilterType {
        switch zone {
        case .beach: return .beach
        case .shallows: return .shallows
        case .deepWater: return .deepWater
        default: return .beach
        }
    }
}

struct ZoneHeaderCard: View {
    let title: String
    let zone: OperationalZone
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            // Indicator badge
            ZStack {
                Circle()
                    .fill(badgeBgColor)
                    .frame(width: 32, height: 32)
                
                Circle()
                    .fill(themeColor)
                    .frame(width: 14, height: 14)
                    .shadow(color: themeColor, radius: 4)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Numeric Swimmer Count
            Text("\(count)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? themeColor : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? themeColor.opacity(0.15) : Color.clear, radius: 6, x: 0, y: 3)
    }
    
    private var themeColor: Color {
        switch zone {
        case .beach: return Color.green
        case .shallows: return Color.yellow
        case .deepWater: return Color.red
        default: return Color.gray
        }
    }
    
    private var badgeBgColor: Color {
        themeColor.opacity(0.15)
    }
    
    private var cardBgColor: Color {
        Color(UIColor.secondarySystemBackground)
    }
}

struct SwimmerRowView: View {
    let swimmer: Swimmer
    @ObservedObject var viewModel: SwimmerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Swimmer \(swimmer.id.prefix(6))")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                        if swimmer.alertLevel != .none {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(swimmer.alertLevel == .red ? .red : .yellow)
                                .font(.system(size: 14))
                        }
                    }
                    
                    HStack(spacing: 12) {
                        Text("HR: \(swimmer.heartRate)")
                            .foregroundColor(swimmer.heartRate > 120 || swimmer.heartRate < 50 ? .red : .secondary)
                        Text("SpO2: \(swimmer.spo2)%")
                            .foregroundColor(swimmer.spo2 < 95 ? .red : .secondary)
                        Text("Depth: \(String(format: "%.1f", swimmer.depthMeters))m")
                            .foregroundColor(.secondary)
                    }
                    .font(.system(size: 12))
                }
                
                Spacer()
                
                // Locate Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 1.0)) {
                        viewModel.selectedSwimmerId = swimmer.id
                        if let coord = swimmer.coordinate {
                            viewModel.mapFocusCoordinate = FocusCoordinate(latitude: coord.latitude, longitude: coord.longitude)
                        }
                    }
                }) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            // Acknowledgment Buttons (Directly inside Sidebar Row)
            if swimmer.alertLevel != .none {
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.resolveAlert(for: swimmer, classification: "REAL_EMERGENCY")
                        }
                    }) {
                        HStack {
                            Image(systemName: "lifepreserver.fill")
                            Text("True Alarm")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(8)
                        .shadow(color: Color.red.opacity(0.3), radius: 3)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            viewModel.resolveAlert(for: swimmer, classification: "FALSE_ALARM")
                        }
                    }) {
                        HStack {
                            Image(systemName: "bell.slash.fill")
                            Text("False Alarm")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.selectedSwimmerId == swimmer.id ? Color.blue.opacity(0.15) : Color(UIColor.secondarySystemBackground).opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(viewModel.selectedSwimmerId == swimmer.id ? Color.blue.opacity(0.5) : Color.primary.opacity(0.04), lineWidth: 1)
        )
        .onTapGesture {
            withAnimation(.spring()) {
                if viewModel.selectedSwimmerId == swimmer.id {
                    viewModel.selectedSwimmerId = nil
                } else {
                    viewModel.selectedSwimmerId = swimmer.id
                    if let coord = swimmer.coordinate {
                        viewModel.mapFocusCoordinate = FocusCoordinate(latitude: coord.latitude, longitude: coord.longitude)
                    }
                }
            }
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var username: String = ""
    @State private var arbourName: String = ""
    @State private var latitudeString: String = ""
    @State private var longitudeString: String = ""
    
    enum LocationMethod {
        case currentLocation
        case manual
    }
    
    @State private var locationMethod: LocationMethod = .manual
    @StateObject private var locationManager = LocationManager()
    
    @State private var errorMessage: String?
    @State private var showLocalAlert = false
    @State private var isSaving = false
    
    enum Field: Hashable {
        case username, arbourName, latitude, longitude
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.04, green: 0.05, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Info Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("OPERATOR DETAILS")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.leading, 4)
                            
                            VStack(spacing: 12) {
                                InputField(
                                    icon: "person.fill",
                                    placeholder: "Username",
                                    text: $username,
                                    isFocused: focusedField == .username
                                )
                                .focused($focusedField, equals: .username)
                                
                                InputField(
                                    icon: "house.fill",
                                    placeholder: "Arbour Name (e.g. Station 1)",
                                    text: $arbourName,
                                    isFocused: focusedField == .arbourName
                                )
                                .focused($focusedField, equals: .arbourName)
                            }
                        }
                        
                        // Location Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("ARBOUR LOCATION COORDINATES")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.leading, 4)
                            
                            HStack(spacing: 0) {
                                Text("Current Location")
                                    .frame(maxWidth: .infinity)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(locationMethod == .currentLocation ? .white : .white.opacity(0.6))
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(locationMethod == .currentLocation ? Color.blue.opacity(0.85) : Color.clear)
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            locationMethod = .currentLocation
                                        }
                                    }
                                
                                Text("Manual Coordinates")
                                    .frame(maxWidth: .infinity)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(locationMethod == .manual ? .white : .white.opacity(0.6))
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(locationMethod == .manual ? Color.blue.opacity(0.85) : Color.clear)
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                            locationMethod = .manual
                                        }
                                    }
                            }
                            .padding(3)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            
                            if locationMethod == .currentLocation {
                                VStack(alignment: .leading, spacing: 8) {
                                    if let location = locationManager.lastLocation {
                                        HStack {
                                            Image(systemName: "mappin.and.ellipse")
                                                .foregroundColor(.green)
                                                .font(.system(size: 18, weight: .bold))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Location Acquired")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundColor(.green)
                                                Text("Lat: \(String(format: "%.6f", location.coordinate.latitude))\nLon: \(String(format: "%.6f", location.coordinate.longitude))")
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.9))
                                            }
                                            Spacer()
                                            Button(action: {
                                                locationManager.startUpdating()
                                            }) {
                                                Image(systemName: "arrow.clockwise")
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .background(Color.white.opacity(0.12))
                                                    .clipShape(Circle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(12)
                                        .background(Color.green.opacity(0.12))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.green.opacity(0.35), lineWidth: 1)
                                        )
                                    } else {
                                        HStack(spacing: 12) {
                                            if locationManager.authorizationStatus == .notDetermined {
                                                Button(action: {
                                                    locationManager.requestPermission()
                                                }) {
                                                    HStack {
                                                        Image(systemName: "location.circle.fill")
                                                        Text("Grant Location Access")
                                                    }
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 12)
                                                    .background(Color.blue)
                                                    .cornerRadius(10)
                                                }
                                                .buttonStyle(.plain)
                                            } else if locationManager.authorizationStatus == .denied || locationManager.authorizationStatus == .restricted {
                                                HStack(alignment: .top, spacing: 10) {
                                                    Image(systemName: "exclamationmark.triangle.fill")
                                                        .foregroundColor(.red)
                                                        .font(.system(size: 18))
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text("Location Access Denied")
                                                            .font(.system(size: 12, weight: .bold))
                                                            .foregroundColor(.red)
                                                        Text("Please enable location services in System Settings, or choose Manual Coordinates.")
                                                            .font(.system(size: 11))
                                                            .foregroundColor(.white.opacity(0.65))
                                                    }
                                                }
                                                .padding(12)
                                                .background(Color.red.opacity(0.12))
                                                .cornerRadius(12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.red.opacity(0.35), lineWidth: 1)
                                                )
                                            } else {
                                                ProgressView()
                                                    .tint(.white)
                                                Text("Acquiring GPS location...")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.7))
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 50)
                                        .onAppear {
                                            if locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways {
                                                locationManager.startUpdating()
                                            }
                                        }
                                        .onChange(of: locationManager.authorizationStatus) { _, newStatus in
                                            if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                                                locationManager.startUpdating()
                                            }
                                        }
                                    }
                                }
                                .transition(.opacity)
                            } else {
                                HStack(spacing: 12) {
                                    InputField(
                                        icon: "scope",
                                        placeholder: "Latitude",
                                        text: $latitudeString,
                                        isFocused: focusedField == .latitude
                                    )
                                    .focused($focusedField, equals: .latitude)
                                    .keyboardType(.numbersAndPunctuation)
                                    
                                    InputField(
                                        icon: "scope",
                                        placeholder: "Longitude",
                                        text: $longitudeString,
                                        isFocused: focusedField == .longitude
                                    )
                                    .focused($focusedField, equals: .longitude)
                                    .keyboardType(.numbersAndPunctuation)
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Profile")
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        handleSave()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .disabled(isSaving)
                }
            }
            .alert(isPresented: $showLocalAlert) {
                Alert(
                    title: Text("Notice"),
                    message: Text(errorMessage ?? "Unknown error"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            if let user = appState.currentUser {
                username = user.username
                arbourName = user.arbourName ?? ""
                latitudeString = String(format: "%.6f", user.arbourLatitude)
                longitudeString = String(format: "%.6f", user.arbourLongitude)
            }
        }
    }
    
    private func handleSave() {
        focusedField = nil
        
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Username cannot be empty.")
            return
        }
        
        let lat: Double
        let lon: Double
        
        if locationMethod == .currentLocation {
            guard let location = locationManager.lastLocation else {
                showError("Current location not acquired yet.")
                return
            }
            lat = location.coordinate.latitude
            lon = location.coordinate.longitude
        } else {
            guard let parsedLat = Double(latitudeString), parsedLat >= -90.0 && parsedLat <= 90.0 else {
                showError("Please enter a valid Latitude between -90 and 90.")
                return
            }
            guard let parsedLon = Double(longitudeString), parsedLon >= -180.0 && parsedLon <= 180.0 else {
                showError("Please enter a valid Longitude between -180 and 180.")
                return
            }
            lat = parsedLat
            lon = parsedLon
        }
        
        isSaving = true
        Task {
            do {
                try await appState.updateProfile(
                    newUsername: username,
                    newArbourName: arbourName,
                    latitude: lat,
                    longitude: lon
                )
                dismiss()
            } catch {
                showError(error.localizedDescription)
            }
            isSaving = false
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showLocalAlert = true
    }
}
