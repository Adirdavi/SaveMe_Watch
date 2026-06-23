//
//  savemeApp.swift
//  saveme Watch App
//
//  Created by Adir Davidov on 01/02/2026.
//

import SwiftUI
import FirebaseCore

@main
struct saveme_Watch_AppApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
