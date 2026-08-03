//
//  NeverSleepApp.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

import SwiftUI

@main
struct NeverSleepApp: App {
    init() {
        // Pure menu-bar app: no Dock icon, no standing main window.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
        } label: {
            // Icon + short value text; 「—」 until the read path lands (Build: read path).
            Label("—", systemImage: "moon.zzz")
        }
        .menuBarExtraStyle(.window)
    }
}
