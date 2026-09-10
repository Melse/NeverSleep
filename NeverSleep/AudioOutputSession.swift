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
    private var eventMonitor: Any?
    private var didTearDown = false

    init(parent: NSPopover, model: AudioOutputModel) {
        self.parent = parent
        self.model = model
        super.init()
        parent.delegate = self
        nested.behavior = .applicationDefined
        nested.delegate = self
        nested.contentViewController = NSHostingController(
            rootView: AudioOutputListView(model: model, session: self)
        )
    }

    func parentDidShow() {
        didTearDown = false
        model.startListening()
    }

    func parentWillClose() {
        guard !didTearDown else { return }
        didTearDown = true
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
        parent?.behavior = .applicationDefined
        installOutsideClickMonitor()
        let edge = preferredEdge(for: anchorView)
        nested.contentSize = NSSize(width: 240, height: min(listHeight(), remainingHeight(from: anchorView)))
        nested.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: edge)
        nested.contentViewController?.view.window?.acceptsMouseMovedEvents = true
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
        let below = windowRect.minY - screen.visibleFrame.minY - 12
        let above = screen.visibleFrame.maxY - windowRect.maxY - 12
        return max(80, max(below, above))
    }

    private func listHeight() -> CGFloat {
        let rows = max(model.devices.count, 1)
        return CGFloat(min(rows, 12)) * 28 + 12
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
        parent?.behavior = .transient
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

    }
}

struct AudioOutputListView: View {
    @Bindable var model: AudioOutputModel
    var session: AudioOutputSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.devices) { device in
                    Button {
                        session.select(device.id)
                    } label: {
                        HStack {
                            Text(device.name)
                                .lineLimit(1)
                            Spacer()
                            if model.isSetting && !device.isCurrent {
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
        }
        .padding(.vertical, 6)
        .frame(minWidth: 220)
        .background(ListTrackingView { hovering in
            if hovering { session.listEntered() } else { session.listExited() }
        })
    }
}

/// Tracks pointer enter/exit even when the nested popover window is not key.
private struct ListTrackingView: NSViewRepresentable {
    var onHover: (Bool) -> Void

    func makeNSView(context: Context) -> HoverView {
        let view = HoverView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: HoverView, context: Context) {
        nsView.onHover = onHover
    }

    final class HoverView: NSView {
        var onHover: ((Bool) -> Void)?
        private var tracking: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            tracking = area
        }

        override func mouseEntered(with event: NSEvent) { onHover?(true) }
        override func mouseExited(with event: NSEvent) { onHover?(false) }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }
}
