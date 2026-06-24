import SwiftUI
import CoreLocation

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
