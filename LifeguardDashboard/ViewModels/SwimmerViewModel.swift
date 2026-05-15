import Foundation
import Combine

@MainActor
class SwimmerViewModel: ObservableObject {
    @Published var sortedSwimmers: [Swimmer] = []
    @Published var activeRedAlert: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        FirebaseManager.shared.swimmersPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] swimmersDict in
                self?.processSwimmers(Array(swimmersDict.values))
            }
            .store(in: &cancellables)
    }
    
    private func processSwimmers(_ swimmers: [Swimmer]) {
        // Sort swimmers so emergencies appear at the top of the list
        self.sortedSwimmers = swimmers.sorted {
            let priority0 = priority(for: $0.alertLevel)
            let priority1 = priority(for: $1.alertLevel)
            
            if priority0 != priority1 {
                return priority0 < priority1
            }
            return $0.id < $1.id
        }
        
        // Handle Red Alert Audio
        let hasRedAlert = swimmers.contains { $0.alertLevel == .red }
        if hasRedAlert && !self.activeRedAlert {
            self.activeRedAlert = true
            AudioService.shared.playAlarm()
        } else if !hasRedAlert && self.activeRedAlert {
            self.activeRedAlert = false
            AudioService.shared.stopAlarm()
        }
    }
    
    private func priority(for level: AlertLevel) -> Int {
        switch level {
        case .red: return 0
        case .yellow: return 1
        case .none: return 2
        }
    }
    
    func silenceAlarm() {
        AudioService.shared.stopAlarm()
        // Here you might optionally write to Firebase to acknowledge the alert
        // so it updates the status for other connected dashboards.
    }
}
