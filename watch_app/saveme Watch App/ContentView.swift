import SwiftUI

struct ContentView: View {
    @AppStorage("isProfileComplete") var isProfileComplete: Bool = false
    @AppStorage("userAge") var userAge: Int = 25
    @AppStorage("userHeight") var userHeight: Double = 1.80
    @AppStorage("userWeight") var userWeight: Double = 75.0
    
    @StateObject var manager = WatchManager()
    
    var body: some View {
        Group {
            if !isProfileComplete {
                setupProfileView
            } else {
                mainWatchView
            }
        }
    }
    
    // --- מסך מילוי הפרטים - הומר לטופס קומפקטי עם גלילה ---
    var setupProfileView: some View {
        Form {
            Section(header: Text("Personalize SaveMe").font(.system(size: 13, weight: .bold))) {
                
                // Picker פותח אוטומטית את מסך הגלילה (הגלגל) של אפל
                Picker("Age", selection: $userAge) {
                    ForEach(10...100, id: \.self) { age in
                        Text("\(age)").tag(age)
                    }
                }
                
                Picker("Height", selection: $userHeight) {
                    ForEach(100...220, id: \.self) { cm in
                        Text("\(cm) cm").tag(Double(cm) / 100.0)
                    }
                }
                
                Picker("Weight", selection: $userWeight) {
                    ForEach(30...150, id: \.self) { kg in
                        Text("\(kg) kg").tag(Double(kg))
                    }
                }
                
                Button(action: {
                    withAnimation {
                        isProfileComplete = true
                    }
                }) {
                    Text("Save & Start")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.green)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
    
    // --- המסך הראשי ---
    var mainWatchView: some View {
        ScrollView {
            ZStack {
                VStack {
                HStack {
                    Spacer()
                    
                    if manager.isSending {
                        ProgressView().frame(width: 30, height: 30)
                    } else {
                        Button(action: {
                            manager.sendData(endpoint: "events", data: ["status": "MANUAL_TEST"], isManual: true)
                        }) {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 30, height: 30)
                        .background(Color.gray.opacity(0.4))
                        .clipShape(Circle())
                    }
                }
                Spacer()
            }
            .padding(.top, 5)
            
            VStack(spacing: 14) {
                // Header Icon
                ZStack {
                    Circle()
                        .fill(manager.isSubmerged ? 
                              LinearGradient(gradient: Gradient(colors: [.blue, .cyan]), startPoint: .top, endPoint: .bottom) : 
                              LinearGradient(gradient: Gradient(colors: [.red, .orange]), startPoint: .top, endPoint: .bottom))
                        .frame(width: 55, height: 55)
                        .shadow(color: manager.isSubmerged ? .blue.opacity(0.6) : .red.opacity(0.6), radius: 8, x: 0, y: 0)
                    
                    Image(systemName: manager.isSubmerged ? "water.waves" : "heart.text.square.fill")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 2)
                
                // Stats Card
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(manager.heartRate))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.red)
                            .shadow(color: .red.opacity(0.5), radius: 2, x: 0, y: 0)
                        Text("BPM").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.gray)
                    }
                    
                    Divider().frame(height: 35).background(Color.white.opacity(0.3))
                    
                    VStack(spacing: 4) {
                        Text("\(Int(manager.currentSpO2))%")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .shadow(color: .cyan.opacity(0.5), radius: 2, x: 0, y: 0)
                        Text("SpO2").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(gradient: Gradient(colors: [Color(white: 0.2), Color(white: 0.1)]), startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                
                if manager.currentDepth > 0 || manager.isSubmerged {
                    HStack(spacing: 15) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.to.line")
                                .foregroundColor(.cyan)
                            Text(String(format: "%.1fm", manager.currentDepth))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        Divider().frame(height: 15).background(Color.white.opacity(0.3))
                        
                        HStack(spacing: 4) {
                            Image(systemName: "thermometer")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f°C", manager.waterTemp))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.2))
                            .overlay(Capsule().stroke(Color.blue.opacity(0.4), lineWidth: 1))
                    )
                }
                
                Spacer().frame(height: 2)
                
                if !manager.isMonitoring {
                    Button(action: {
                        manager.requestAuthorization()
                    }) {
                        Text("Start Sensors")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(gradient: Gradient(colors: [.yellow, .orange]), startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(25)
                            .shadow(color: .orange.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    VStack(spacing: 10) {
                        Text(manager.isSubmerged ? "DIVE DETECTED" : "SENSORS ACTIVE")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(manager.isSubmerged ? .cyan : .green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(manager.isSubmerged ? Color.cyan.opacity(0.2) : Color.green.opacity(0.2))
                            )
                        
                        HStack(spacing: 4) {
                            Image(systemName: manager.currentLocation != nil ? "location.fill" : "location.slash")
                            Text(manager.currentLocation != nil ? "GPS Locked" : "Searching GPS")
                        }
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(manager.currentLocation != nil ? .green : .gray)
                        
                        Button(action: {
                            manager.stopMonitoring()
                        }) {
                            Text("Stop Sensors")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LinearGradient(gradient: Gradient(colors: [.red, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .cornerRadius(25)
                                .shadow(color: .red.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Toggle(isOn: $manager.isDemoMode) {
                            Text("Demo Mode")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .tint(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.15))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.top, 20)
        }
        .padding(8)
        } // Close ScrollView

        .alert(item: Binding<AlertMessage?>(
            get: { manager.alertMessage.map { AlertMessage(text: $0) } },
            set: { _ in manager.alertMessage = nil }
        )) { msg in
            Alert(
                title: Text("System Status"),
                message: Text(msg.text),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}

#Preview {
    ContentView()
}
