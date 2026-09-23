//
//  GymAppNativeWatchApp.swift
//  GymAppNativeWatch Watch App
//
//  Created by Néstor Codina on 23/09/2026.
//

import SwiftUI

@main
struct GymAppNativeWatch_Watch_AppApp: App {
    @StateObject private var connectivity = WatchWorkoutConnectivity()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
    }
}
