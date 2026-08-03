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

        // Fixed width: the label width must not change when the value's digit
        // count changes (1→60→180), or the popover anchor drifts.
        let item = NSStatusBar.system.statusItem(withLength: 56)
        if let button = item.button {
            button.alignment = .right
            button.action = #selector(togglePopover(_:))
            button.target = self
            updateMenuBarTitle()
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

    /// Menu bar label: moon icon as a text attachment + monospaced-digit value,
    /// right-aligned in the fixed-width item. One text line keeps the icon and
    /// digits on the same baseline.
    private func updateMenuBarTitle() {
        guard let button = statusItem?.button else { return }
        let attachment = NSTextAttachment()
        attachment.image = NSImage(systemSymbolName: "moon.zzz", accessibilityDescription: "NeverSleep")
        attachment.bounds = NSRect(x: 0, y: -1.5, width: 14, height: 14)
        let attributed = NSMutableAttributedString(attachment: attachment)
        attributed.append(NSAttributedString(
            string: "  \(model.menuBarText)",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        ))
        button.attributedTitle = attributed
    }

    /// Observation-based menu bar title updates: re-register on every change.
    private func observeModelChanges() {
        withObservationTracking {
            _ = model.menuBarText
        } onChange: {
            Task { @MainActor in
                self.updateMenuBarTitle()
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
