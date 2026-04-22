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
    private let deviceID = WKInterfaceDevice.current().identifierForVendor?.uuidString ?? "unknown_device"
    
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "net.path.monitor")
    
    // קלוז'ר (Callback) לעדכון הסטטוס ב-UI
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
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
        } catch {
            completion(false, "שגיאת קידוד נתונים")
            return
        }

        URLSession.shared.dataTask(with: request) { _, _, error in
            if error != nil {
                completion(false, "שגיאת תקשורת")
            } else {
                completion(true, "נשמר ב-Firebase!")
            }
        }.resume()
    }
}
