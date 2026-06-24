import AVFoundation
import Foundation

class AudioService {
  static let shared = AudioService()

  private var redPlayer: AVAudioPlayer?
  private var yellowPlayer: AVAudioPlayer?

  private init() {
    setupAudio()
  }

  private func setupAudio() {
    // Configure audio session to play sound even if the device is set to silent/vibrate
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to configure audio session: \(error)")
    }

    // 1. Setup Red Alarm
    if let redUrl = Bundle.main.url(forResource: "alarm", withExtension: "mp3") {
      do {
        redPlayer = try AVAudioPlayer(contentsOf: redUrl)
        redPlayer?.numberOfLoops = -1
        redPlayer?.prepareToPlay()
      } catch {
        print("Failed to init red audio player from file: \(error)")
      }
    }
    
    // Fallback: Generate wailing siren for red alerts
    if redPlayer == nil {
      if let redData = generateWailingSirenTone(lowFreq: 600.0, highFreq: 1500.0, sweepDuration: 4.0, totalDuration: 4.0) {
        do {
          redPlayer = try AVAudioPlayer(data: redData)
          redPlayer?.numberOfLoops = -1
          redPlayer?.prepareToPlay()
          print("Red alarm synthetic siren generated successfully.")
        } catch {
          print("Failed to init red audio player from synthetic data: \(error)")
        }
      }
    }

    // 2. Setup Yellow Alarm
    if let yellowUrl = Bundle.main.url(forResource: "warning", withExtension: "mp3") {
      do {
        yellowPlayer = try AVAudioPlayer(contentsOf: yellowUrl)
        yellowPlayer?.numberOfLoops = -1
        yellowPlayer?.prepareToPlay()
      } catch {
        print("Failed to init yellow audio player from file: \(error)")
      }
    }
    
    // Fallback: Generate fast yelp siren for yellow alerts
    if yellowPlayer == nil {
      if let yellowData = generateWailingSirenTone(lowFreq: 500.0, highFreq: 1200.0, sweepDuration: 0.5, totalDuration: 2.0) {
        do {
          yellowPlayer = try AVAudioPlayer(data: yellowData)
          yellowPlayer?.numberOfLoops = -1
          yellowPlayer?.prepareToPlay()
          print("Yellow alarm synthetic siren generated successfully.")
        } catch {
          print("Failed to init yellow audio player from synthetic data: \(error)")
        }
      }
    }
  }

  /// Plays a repeating red alarm sound. If yellow is playing, it will be stopped.
  func playRedAlarm() {
    // Stop yellow if it's playing
    if let yPlayer = yellowPlayer, yPlayer.isPlaying {
      yPlayer.stop()
      yPlayer.currentTime = 0
    }
    
    if let rPlayer = redPlayer, !rPlayer.isPlaying {
      rPlayer.play()
    }
  }

  /// Plays a repeating yellow alarm sound. If red is playing, it takes priority and yellow is skipped.
  func playYellowAlarm() {
    // Red alarm has priority. If it's already active/playing, do not play yellow.
    if let rPlayer = redPlayer, rPlayer.isPlaying {
      return
    }
    
    if let yPlayer = yellowPlayer, !yPlayer.isPlaying {
      yPlayer.play()
    }
  }

  /// Stops all alarms.
  func stopAlarm() {
    if let rPlayer = redPlayer, rPlayer.isPlaying {
      rPlayer.stop()
      rPlayer.currentTime = 0
    }
    if let yPlayer = yellowPlayer, yPlayer.isPlaying {
      yPlayer.stop()
      yPlayer.currentTime = 0
    }
  }
  
  // MARK: - Tone Generation Helper
  
  private func generateWailingSirenTone(lowFreq: Double, highFreq: Double, sweepDuration: Double, totalDuration: Double, sampleRate: Double = 44100) -> Data? {
      let numSamples = Int(sampleRate * totalDuration)
      var data = Data()
      
      // RIFF header
      data.append("RIFF".data(using: .utf8)!)
      let fileLength = UInt32(36 + numSamples * 2)
      withUnsafeBytes(of: fileLength.littleEndian) { data.append(contentsOf: $0) }
      data.append("WAVE".data(using: .utf8)!)
      
      // fmt subchunk
      data.append("fmt ".data(using: .utf8)!)
      let subchunk1Size = UInt32(16)
      withUnsafeBytes(of: subchunk1Size.littleEndian) { data.append(contentsOf: $0) }
      let audioFormat = UInt16(1) // PCM
      withUnsafeBytes(of: audioFormat.littleEndian) { data.append(contentsOf: $0) }
      let numChannels = UInt16(1) // Mono
      withUnsafeBytes(of: numChannels.littleEndian) { data.append(contentsOf: $0) }
      let sRate = UInt32(sampleRate)
      withUnsafeBytes(of: sRate.littleEndian) { data.append(contentsOf: $0) }
      let byteRate = UInt32(sampleRate * 2)
      withUnsafeBytes(of: byteRate.littleEndian) { data.append(contentsOf: $0) }
      let blockAlign = UInt16(2)
      withUnsafeBytes(of: blockAlign.littleEndian) { data.append(contentsOf: $0) }
      let bitsPerSample = UInt16(16)
      withUnsafeBytes(of: bitsPerSample.littleEndian) { data.append(contentsOf: $0) }
      
      // data subchunk
      data.append("data".data(using: .utf8)!)
      let subchunk2Size = UInt32(numSamples * 2)
      withUnsafeBytes(of: subchunk2Size.littleEndian) { data.append(contentsOf: $0) }
      
      // Generate wailing siren (frequency sweeps up and down)
      var phase: Double = 0.0
      for i in 0..<numSamples {
          let time = Double(i) / sampleRate
          let sweepPosition = time.truncatingRemainder(dividingBy: sweepDuration) / sweepDuration
          
          // Triangle wave for frequency modulation (0.0 to 1.0 to 0.0)
          let fm = sweepPosition < 0.5 ? (sweepPosition * 2.0) : (2.0 - sweepPosition * 2.0)
          let currentFreq = lowFreq + (highFreq - lowFreq) * fm
          
          phase += 2.0 * .pi * currentFreq / sampleRate
          if phase > 2.0 * .pi {
              phase -= 2.0 * .pi
          }
          
          // We can add some harmonics to make it sound richer/harsher like a real siren
          let val1 = sin(phase)
          let val2 = 0.3 * sin(3.0 * phase) // 3rd harmonic
          let val3 = 0.1 * sin(5.0 * phase) // 5th harmonic
          
          var val = val1 + val2 + val3
          // normalize roughly
          if val > 1.0 { val = 1.0 }
          if val < -1.0 { val = -1.0 }
          
          let sample = Int16(val * 32767.0)
          withUnsafeBytes(of: sample.littleEndian) { data.append(contentsOf: $0) }
      }
      
      return data
  }
}
