import SwiftUI

struct AlertCard: View {
    let title: String
    let severity: SwimmerFilterType // .red, .yellow, .green, or .outOfWater
    let iconName: String
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon Badge
            ZStack {
                Circle()
                    .fill(badgeBgColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(themeColor)
            }
            
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(themeColor)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBgColor)
        )
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeColor.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: themeColor.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    private var themeColor: Color {
        switch severity {
        case .red: return Color.red
        case .yellow: return Color.orange
        case .green: return Color.green
        case .outOfWater: return Color.gray
        }
    }
    
    private var badgeBgColor: Color {
        themeColor.opacity(0.12)
    }
    
    private var cardBgColor: Color {
        Color(UIColor.secondarySystemBackground)
    }
}

