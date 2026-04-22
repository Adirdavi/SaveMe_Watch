import SwiftUI

struct ContentView: View {
    // יוצר חיבור למנהל השעון הראשי שמנצח על הכל
    @StateObject var manager = WatchManager()
    
    var body: some View {
        ZStack {
            // --- אזור עליון - כפתור ענן בלבד ---
            VStack {
                HStack {
                    Spacer() // דוחף את כפתור הענן ימינה בצורה נקייה
                    
                    // כפתור ענן לשליחת ניסיון יזומה
                    if manager.isSending {
                        ProgressView().frame(width: 30, height: 30)
                    } else {
                        Button(action: {
                            // שימוש בפונקציית מעטפת שיצרנו ב-WatchManager
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
            
            // --- העיצוב המרכזי - נתוני רפואה וצלילה ---
            VStack(spacing: 6) {
                
                // אייקון סטטוס מצב מים (כחול למים, אדום ליבשה)
                Image(systemName: manager.isSubmerged ? "water.waves" : "heart.text.square.fill")
                    .font(.system(size: 32))
                    .foregroundColor(manager.isSubmerged ? .blue : .red)
                
                // נתוני לב וחמצן
                HStack {
                    VStack {
                        Text("\(Int(manager.heartRate))")
                            .font(.title2).fontWeight(.bold).foregroundColor(.red)
                        Text("BPM").font(.caption2).foregroundColor(.gray)
                    }
                    
                    Text("|").foregroundColor(.gray).font(.title3)
                    
                    VStack {
                        Text("\(Int(manager.currentSpO2))%")
                            .font(.title2).fontWeight(.bold).foregroundColor(.cyan)
                        Text("SpO2").font(.caption2).foregroundColor(.gray)
                    }
                }
                
                // נתוני צלילה (מוצגים רק אם במים, או אם יש נתונים)
                if manager.currentDepth > 0 || manager.isSubmerged {
                    HStack {
                        Text(String(format: "%.1fm", manager.currentDepth))
                            .foregroundColor(.blue)
                        Text("|")
                        Text(String(format: "%.1f°C", manager.waterTemp))
                            .foregroundColor(.orange)
                    }
                    .font(.subheadline)
                    .padding(.top, 2)
                }
                
                Spacer().frame(height: 10)
                
                // כפתורי הפעלה / סטטוס
                if !manager.isMonitoring {
                    Button(action: {
                        manager.requestAuthorization()
                    }) {
                        Text("Start Sensors")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .background(Color.yellow)
                    .cornerRadius(15)
                } else {
                    // סטטוס מערכת
                    VStack(spacing: 2) {
                        Text(manager.isSubmerged ? "DIVE DETECTED" : "Sensors Active")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(manager.isSubmerged ? .blue : .green)
                        
                        // חיווי קליטת GPS
                        HStack {
                            Image(systemName: manager.currentLocation != nil ? "location.fill" : "location.slash")
                            Text(manager.currentLocation != nil ? "GPS Locked" : "Searching GPS")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(manager.currentLocation != nil ? .green : .gray)
                    }
                }
            }
            .padding(.top, 20)
        }
        .padding(8)
        
        // --- הודעת קופצת (Alert) בסיום השליחה ---
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

// עזר להצגת Alert עם טקסט משתנה
struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}

#Preview {
    ContentView()
}
