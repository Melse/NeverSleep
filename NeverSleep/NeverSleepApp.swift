//
//  NeverSleepApp.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

import SwiftUI

@main
struct NeverSleepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Placeholder scene: the real UI lives in the status item + popover
        // (AppDelegate). No Dock icon, no standing main window.
        Settings {
            EmptyView()
        }
    }
}
