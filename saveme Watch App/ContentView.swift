import SwiftUI

struct ContentView: View {
    // יוצר חיבור למנהל השעון
    @StateObject var manager = WatchManager()
    
    var body: some View {
        ZStack {
            // --- כפתור ענן בפינה השמאלית העליונה ---
            VStack {
                HStack {
                    if manager.isSending {
                        // מציג גלגל טעינה קטן במקום הכפתור בזמן "חשיבה"
                        ProgressView()
                            .frame(width: 40, height: 40)
                    } else {
                        Button(action: {
                            // הפעלת שליחה ידנית עם מצב טעינה
                            manager.manualUpload()
                        }) {
                            Image(systemName: "icloud.and.arrow.up")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                Spacer()
            }
            
            // --- העיצוב המרכזי ---
            VStack {
                // אייקון שמשתנה אם יש מים
                Image(systemName: manager.isSubmerged ? "water.waves" : "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(manager.isSubmerged ? .blue : .red)
                    .padding(.bottom, 5)
                
                // נתונים ראשיים
                VStack(spacing: 8) {
                    Text("\(Int(manager.heartRate)) BPM")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    HStack {
                        Text(String(format: "%.1fm", manager.currentDepth))
                            .foregroundColor(.blue)
                        Text("|")
                        Text(String(format: "%.1f°C", manager.waterTemp))
                            .foregroundColor(.orange)
                    }
                    .font(.headline)
                }
                .padding()
                
                // כפתור התחלה או סטטוס
                if !manager.isMonitoring {
                    Button(action: {
                        manager.requestAuthorization()
                    }) {
                        Text("Start Monitor")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                    }
                    .background(Color.yellow)
                    .cornerRadius(20)
                } else {
                    Text(manager.isSubmerged ? "UNDERWATER ACTIVE" : "Monitoring...")
                        .font(.caption)
                        .foregroundColor(manager.isSubmerged ? .cyan : .green)
                        .padding(.top, 5)
                }
            }
        }
        .padding()
        // --- הודעת קופצת (Alert) בסיום השליחה ---
        .alert(item: Binding<AlertMessage?>(
            get: { manager.alertMessage.map { AlertMessage(text: $0) } },
            set: { _ in manager.alertMessage = nil }
        )) { msg in
            Alert(
                title: Text("Firebase Status"),
                message: Text(msg.text),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

// עזר להצגת Alert עם טקסט משתנה
struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}

#Preview {
    ContentView()
}
