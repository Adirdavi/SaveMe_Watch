import SwiftUI
import CoreLocation

enum AuthField: Hashable {
    case username, password, latitude, longitude
}

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    
    enum LocationMethod {
        case currentLocation
        case manual
    }
    
    // View state
    @State private var isSignUp = false
    @State private var username = ""
    @State private var password = ""
    @State private var latitudeString = ""
    @State private var longitudeString = ""
    @State private var locationMethod: LocationMethod = .currentLocation
    @StateObject private var locationManager = LocationManager()
    
    // Validation alert state
    @State private var localErrorMessage: String? = nil
    @State private var showLocalAlert = false
    
    // Interactive styling state
    @FocusState private var focusedField: AuthField?
    @State private var animateBackground = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            // Auth Box
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 30) {
                        Spacer()
                            .frame(height: 50)
                        
                        headerView
                        
                        // Glassmorphism Card
                        VStack(spacing: 24) {
                            switcherSection
                            
                            // Inputs Form
                            VStack(spacing: 16) {
                                // Username
                                InputField(
                                    icon: "person.fill",
                                    placeholder: "Username",
                                    text: $username,
                                    isFocused: focusedField == .username
                                )
                                .id(AuthField.username)
                                .focused($focusedField, equals: .username)
                                .textContentType(.username)
                                .submitLabel(.next)
                                
                                // Password
                                SecureInputField(
                                    icon: "lock.fill",
                                    placeholder: "Password",
                                    text: $password,
                                    isFocused: focusedField == .password
                                )
                                .id(AuthField.password)
                                .focused($focusedField, equals: .password)
                                .textContentType(.password)
                                .submitLabel(isSignUp ? .next : .done)
                                
                                // Arbour Coordinates (Only for Sign Up)
                                if isSignUp {
                                    signUpLocationSection
                                }
                            }
                            
                            submitButton
                            
                            // Info Text / Helper
                            if isSignUp {
                                Text("Note: Coordinates configure the map dashboard center and represent your primary lifeguard arbour response area.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.06))
                                .background(.ultraThinMaterial)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.03)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 25, x: 0, y: 15)
                        .padding(.horizontal, 20)
                        .frame(maxWidth: 500)
                        
                        Spacer()
                    }
                    .padding(.bottom, focusedField != nil ? 260 : 40)
                }
                .onChange(of: focusedField) { newField in
                    if let field = newField {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(field, anchor: .center)
                        }
                    }
                }
            }
        }
        .onSubmit {
            switch focusedField {
            case .username:
                focusedField = .password
            case .password:
                if isSignUp {
                    focusedField = .latitude
                } else {
                    handleAuth()
                }
            case .latitude:
                focusedField = .longitude
            case .longitude:
                handleAuth()
            case nil:
                break
            }
        }
        // Alerts
        .alert(isPresented: $showLocalAlert) {
            Alert(
                title: Text("Validation Error"),
                message: Text(localErrorMessage ?? "Unknown input validation issue."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $appState.showAlert) {
            Alert(
                title: Text("Authentication Failed"),
                message: Text(appState.errorMessage ?? "An error occurred during authentication."),
                dismissButton: .default(Text("Dismiss"))
            )
        }
    }
    
    // MARK: - Extracted Helper Subviews
    
    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.05, blue: 0.12), Color(red: 0.08, green: 0.12, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated Glowing Orb 1
            Circle()
                .fill(Color.teal.opacity(0.18))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: animateBackground ? -100 : 100, y: animateBackground ? -150 : 150)
            
            // Animated Glowing Orb 2
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 350, height: 350)
                .blur(radius: 70)
                .offset(x: animateBackground ? 150 : -150, y: animateBackground ? 100 : -100)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(Animation.linear(duration: 12.0).repeatForever(autoreverses: true)) {
                animateBackground = true
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lifepreserver.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
                    .shadow(color: .blue.opacity(0.8), radius: 10)
            }
            
            Text("SAVEME")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(4)
            
            Text("Lifeguard Tactical Operations Center")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var switcherSection: some View {
        HStack(spacing: 0) {
            Text("Sign In")
                .frame(maxWidth: .infinity)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isSignUp ? .white.opacity(0.6) : .white)
                .padding(.vertical, 12)
                .background(isSignUp ? Color.clear : Color.blue)
                .cornerRadius(12)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSignUp = false
                    }
                }
            
            Text("Sign Up")
                .frame(maxWidth: .infinity)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(isSignUp ? .white : .white.opacity(0.6))
                .padding(.vertical, 12)
                .background(isSignUp ? Color.blue : Color.clear)
                .cornerRadius(12)
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isSignUp = true
                    }
                }
        }
        .padding(4)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var locationMethodSelector: some View {
        HStack(spacing: 0) {
            Text("Current Location")
                .frame(maxWidth: .infinity)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(locationMethod == .currentLocation ? .white : .white.opacity(0.6))
                .padding(.vertical, 8)
                .background(locationMethod == .currentLocation ? Color.blue.opacity(0.85) : Color.clear)
                .cornerRadius(8)
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
                .background(locationMethod == .manual ? Color.blue.opacity(0.85) : Color.clear)
                .cornerRadius(8)
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
    }
    
    private var submitButton: some View {
        Button(action: handleAuth) {
            HStack {
                Spacer()
                if appState.isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                        .padding(.trailing, 8)
                    Text("Securing Session...")
                } else {
                    Text(isSignUp ? "Create Operation Desk" : "Authorize Station")
                }
                Spacer()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color(red: 0.1, green: 0.5, blue: 0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(14)
            .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(appState.isLoading)
    }
    
    private var signUpLocationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 4, height: 16)
                Text("Arbour Location Coordinates")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.top, 4)
            
            locationMethodSelector
            
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
                        placeholder: "Latitude (e.g. 32.08)",
                        text: $latitudeString,
                        isFocused: focusedField == .latitude
                    )
                    .id(AuthField.latitude)
                    .focused($focusedField, equals: .latitude)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.next)
                    
                    InputField(
                        icon: "scope",
                        placeholder: "Longitude (e.g. 34.78)",
                        text: $longitudeString,
                        isFocused: focusedField == .longitude
                    )
                    .id(AuthField.longitude)
                    .focused($focusedField, equals: .longitude)
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.done)
                }
                .transition(.opacity)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // MARK: - Validation & Auth Submission
    private func handleAuth() {
        // Clear keyboard focus
        focusedField = nil
        
        // 1. Basic Fields Validation
        guard !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Username field cannot be empty.")
            return
        }
        guard password.count >= 6 else {
            showError("Password must be at least 6 characters.")
            return
        }
        
        // 2. Extra Validation for Sign Up
        if isSignUp {
            let lat: Double
            let lon: Double
            
            if locationMethod == .currentLocation {
                guard let location = locationManager.lastLocation else {
                    showError("Current location not acquired yet. Please wait for GPS lock, or use manual coordinates.")
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
            
            // Perform asynchronous Sign Up call
            Task {
                await appState.signUp(username: username, password: password, latitude: lat, longitude: lon)
            }
        } else {
            // Perform asynchronous Sign In call
            Task {
                await appState.signIn(username: username, password: password)
            }
        }
    }
    
    private func showError(_ message: String) {
        localErrorMessage = message
        showLocalAlert = true
    }
}

// MARK: - Subcomponents & Helpers

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isFocused ? .blue : .white.opacity(0.4))
                .frame(width: 20)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.spring(), value: isFocused)
            
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .foregroundColor(.white)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .autocapitalization(.none)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(isFocused ? 0.05 : 0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.blue.opacity(0.8) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

struct SecureInputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(isFocused ? .blue : .white.opacity(0.4))
                .frame(width: 20)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(.spring(), value: isFocused)
            
            SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.35)))
                .foregroundColor(.white)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .autocapitalization(.none)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(isFocused ? 0.05 : 0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFocused ? Color.blue.opacity(0.8) : Color.white.opacity(0.08), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// Deleted VisualEffectBlur struct in favor of standard SwiftUI Materials
