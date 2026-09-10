//
//  AudioOutputSession.swift
//  NeverSleep
//
//  Created by Melse on 2026/9/10.
//

import AppKit
import CoreAudio
import SwiftUI

/// Owns nested device-list popover show/hide and confirmed parent dismiss.
@Observable
final class AudioOutputSession: NSObject, NSPopoverDelegate {
    private weak var parent: NSPopover?
    private let model: AudioOutputModel
    private let nested = NSPopover()
    private var anchorView: NSView?
    private var openWorkItem: DispatchWorkItem?
    private var closeWorkItem: DispatchWorkItem?
    private var pointerInRow = false
    private var pointerInList = false
    private var fallbackRung = "default"
    private var parentWasTransient = true
    private var eventMonitor: Any?

    var lastFallbackRung: String { fallbackRung }

    init(parent: NSPopover, model: AudioOutputModel) {
        self.parent = parent
        self.model = model
        super.init()
        nested.behavior = .applicationDefined
        nested.delegate = self
        nested.contentViewController = NSHostingController(
            rootView: AudioOutputListView(model: model, session: self)
        )
    }

    func attachParent(_ parent: NSPopover) {
        self.parent = parent
        parent.delegate = self
    }

    func parentDidShow() {
        model.startListening()
    }

    func parentWillClose() {
        cancelTimers()
        hideList()
        model.stopListening()
        restoreParentTransientIfNeeded()
    }

    func rowEntered(anchor: NSView) {
        pointerInRow = true
        anchorView = anchor
        cancelClose()
        guard !nested.isShown else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.showList()
        }
        openWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    func rowExited() {
        pointerInRow = false
        openWorkItem?.cancel()
        openWorkItem = nil
        scheduleCloseIfNeeded()
    }

    func listEntered() {
        pointerInList = true
        cancelClose()
    }

    func listExited() {
        pointerInList = false
        scheduleCloseIfNeeded()
    }

    func otherContentEntered() {
        pointerInRow = false
        openWorkItem?.cancel()
        openWorkItem = nil
        hideList()
    }

    func select(_ id: AudioObjectID) {
        Task { @MainActor in
            let outcome = await model.select(id)
            switch outcome {
            case .alreadyCurrent, .confirmed:
                dismissParentAfterSelect()
            case .failed, .pendingConfirm:
                break
            }
        }
    }

    private func showList() {
        guard let anchorView, parent?.isShown == true else { return }
        if nested.isShown { return }
        let edge = preferredEdge(for: anchorView)
        nested.contentSize = NSSize(width: 240, height: min(listHeight(), remainingHeight(from: anchorView)))
        enableFirstMouse(in: nested)
        nested.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: edge)
        if parent?.isShown != true {
            parent?.behavior = .applicationDefined
            parentWasTransient = true
            fallbackRung = "parent-applicationDefined"
            if let parent, let button = anchorView.window.map({ _ in anchorView }) {
                _ = button
            }
            parent?.show(
                relativeTo: parentAnchorRect(),
                of: parentAnchorView() ?? anchorView,
                preferredEdge: .minY
            )
            nested.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: edge)
            installOutsideClickMonitor()
            if parent?.isShown != true {
                fallbackRung = "child-window"
            }
        }
    }

    private func hideList() {
        if nested.isShown {
            nested.performClose(nil)
        }
        restoreParentTransientIfNeeded()
    }

    private func dismissParentAfterSelect() {
        hideList()
        parent?.performClose(nil)
    }

    private func scheduleCloseIfNeeded() {
        guard !pointerInRow && !pointerInList else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.pointerInRow, !self.pointerInList else { return }
            self.hideList()
        }
        closeWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: work)
    }

    private func cancelClose() {
        closeWorkItem?.cancel()
        closeWorkItem = nil
    }

    private func cancelTimers() {
        openWorkItem?.cancel()
        openWorkItem = nil
        cancelClose()
    }

    private func preferredEdge(for view: NSView) -> NSRectEdge {
        guard let screen = view.window?.screen ?? NSScreen.main else { return .maxX }
        let rect = view.convert(view.bounds, to: nil)
        let windowRect = view.window?.convertToScreen(rect) ?? rect
        let space = screen.visibleFrame.maxX - windowRect.maxX
        return space >= 250 ? .maxX : .minX
    }

    private func remainingHeight(from view: NSView) -> CGFloat {
        guard let screen = view.window?.screen ?? NSScreen.main else { return 280 }
        let rect = view.convert(view.bounds, to: nil)
        let windowRect = view.window?.convertToScreen(rect) ?? rect
        return max(80, screen.visibleFrame.maxY - windowRect.minY - 12)
    }

    private func listHeight() -> CGFloat {
        let rows = max(model.devices.count, 1)
        return CGFloat(min(rows, 12)) * 28 + 12
    }

    private func enableFirstMouse(in popover: NSPopover) {
        popover.contentViewController?.view.window?.acceptsMouseMovedEvents = true
    }

    private func parentAnchorView() -> NSView? {
        parent?.contentViewController?.view
    }

    private func parentAnchorRect() -> NSRect {
        parentAnchorView()?.bounds ?? .zero
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            let inNested = event.window == self.nested.contentViewController?.view.window
            let inParent = event.window == self.parent?.contentViewController?.view.window
            if !inNested && !inParent {
                self.parent?.performClose(nil)
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func restoreParentTransientIfNeeded() {
        removeOutsideClickMonitor()
        if parentWasTransient {
            parent?.behavior = .transient
        }
    }

    func popoverWillClose(_ notification: Notification) {
        guard notification.object as? NSPopover === parent else { return }
        parentWillClose()
    }
}

/// Reports the SwiftUI row's AppKit view so the nested popover can anchor to it.
struct AudioRowAnchor: NSViewRepresentable {
    var onView: (NSView) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onView = onView
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        nsView.onView = onView
        DispatchQueue.main.async { onView(nsView) }
    }

    final class TrackingView: NSView {
        var onView: ((NSView) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let onView { onView(self) }
        }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}

struct AudioOutputListView: View {
    @Bindable var model: AudioOutputModel
    var session: AudioOutputSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(model.devices) { device in
                Button {
                    session.select(device.id)
                } label: {
                    HStack {
                        Text(device.name)
                            .lineLimit(1)
                        Spacer()
                        if model.isSetting && device.isCurrent == false {
                            ProgressView()
                                .controlSize(.small)
                        } else if device.isCurrent {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.isSetting)
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 220)
        .background(
            AudioRowAnchor { _ in }
                .onHover { hovering in
                    if hovering { session.listEntered() } else { session.listExited() }
                }
        )
        .onHover { hovering in
            if hovering { session.listEntered() } else { session.listExited() }
        }
    }
}
