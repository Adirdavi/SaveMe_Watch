//
//  FirebaseService.swift
//  saveme Watch App
//
//  Created by Adir Davidov on 22/04/2026.
//

import Foundation
import Network
import WatchKit

class FirebaseService {
    private let databaseURL = "https://saveme-5666b-default-rtdb.europe-west1.firebasedatabase.app"
    
    private var deviceID: String {
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        if !name.isEmpty {
            return name
        }
        return WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown_device"
    }
    
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.path.monitor")
    
    // Callback to update the UI status
    var onNetworkUpdate: ((Bool) -> Void)?

    init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.onNetworkUpdate?(path.status == .satisfied)
        }
        pathMonitor.start(queue: pathQueue)
    }

    deinit {
        pathMonitor.cancel()
    }

    func send(endpoint: String, data: [String: Any], isManual: Bool = false, completion: @escaping (Bool, String?) -> Void) {
        let fullPath = "devices/\(deviceID)/\(endpoint)"
        guard let url = URL(string: "\(databaseURL)/\(fullPath).json") else { return }

        var request = URLRequest(url: url)
        
        // Use PUT for live_monitor and active_warnings to overwrite and keep only the latest state
        // Use POST for events to maintain a history log
        if endpoint == "live_monitor" || endpoint == "active_warnings" {
            request.httpMethod = "PUT"
        } else {
            request.httpMethod = "POST"
        }
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            completion(false, "Data encoding error")
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                completion(false, "Network error")
            } else {
                completion(true, "Saved to Firebase!")
            }
        }.resume()
    }

    func updateUserProfile(name: String, age: Int, height: Double, weight: Double, gender: String) {
        let fullPath = "devices/\(deviceID)/profile"
        guard let url = URL(string: "\(databaseURL)/\(fullPath).json") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let data: [String: Any] = [
            "age": age,
            "height": height,
            "weight": weight,
            "gender": gender
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            return
        }

        URLSession.shared.dataTask(with: request).resume()
    }
}
