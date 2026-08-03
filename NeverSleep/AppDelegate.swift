//
//  AppDelegate.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

import AppKit
import Observation
import SwiftUI

/// Owns the menu bar status item and popover (MenuBarExtra's label text does
/// not reliably render on macOS — NSStatusItem gives full control).
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let model = DisplayOffModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "NeverSleep")
            button.imagePosition = .imageLeading
            button.title = model.menuBarText
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item

        let hosting = NSHostingController(rootView: PopoverView().environment(model))
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = hosting
        popover.contentSize = hosting.view.fittingSize
        self.popover = popover

        observeModelChanges()
        Task { await model.read() }
    }

    /// Observation-based menu bar title updates: re-register on every change.
    private func observeModelChanges() {
        withObservationTracking {
            _ = model.menuBarText
        } onChange: {
            Task { @MainActor in
                self.statusItem?.button?.title = self.model.menuBarText
                self.observeModelChanges()
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        if popover?.isShown == true {
            popover?.performClose(sender)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }
}
