import Foundation
import AVFoundation

class AudioService {
    static let shared = AudioService()
    
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        setupAudio()
    }
    
    private func setupAudio() {
        // We assume an "alarm.mp3" file is added to the Xcode project.
        guard let url = Bundle.main.url(forResource: "alarm", withExtension: "mp3") else { 
            print("Alarm sound file not found in bundle.")
            return 
        }
        
        do {
            // Configure audio session to play even if the device is on silent (optional but recommended for lifeguards)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Infinite loop
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to setup audio player: \(error)")
        }
    }
    
    func playAlarm() {
        if let player = audioPlayer, !player.isPlaying {
            player.play()
        }
    }
    
    func stopAlarm() {
        if let player = audioPlayer, player.isPlaying {
            player.stop()
            player.currentTime = 0
        }
    }
}
