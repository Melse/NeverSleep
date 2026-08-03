//
//  PopoverView.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

import AppKit
import SwiftUI

/// The 13 system stops, left→right: Never(0) … 180 minutes. Equidistant on track.
nonisolated let displayOffStops: [Int] = [0, 1, 2, 3, 5, 10, 20, 30, 60, 90, 120, 150, 180]

/// System-aligned wording for a display-off value in minutes. Full localization
/// lands in Build: localization and verification checklist.
nonisolated func displayOffStopLabel(_ minutes: Int) -> String {
    switch minutes {
    case 0: return "永不"
    case 1: return "1 分钟"
    case 60: return "1 小时"
    case 90: return "1 小时 30 分钟"
    case 120: return "2 小时"
    case 150: return "2 小时 30 分钟"
    case 180: return "3 小时"
    default: return "\(minutes) 分钟"
    }
}

/// Snap slider over the 13 stop indexes (0…12), equidistant, with a tick row.
/// `onCommit` fires when the user releases the thumb.
struct DisplayOffSlider: View {
    @Binding var index: Int
    var disabled = false
    var onCommit: () -> Void = {}

    var body: some View {
        VStack(spacing: 5) {
            Slider(
                value: Binding(
                    get: { Double(index) },
                    set: { index = Int($0.rounded()) }
                ),
                in: 0...12,
                step: 1,
                onEditingChanged: { editing in
                    if !editing { onCommit() }
                }
            )
            .disabled(disabled)
            HStack(spacing: 0) {
                ForEach(0..<13, id: \.self) { i in
                    Capsule()
                        .fill(index == i ? Color.accentColor : Color.secondary.opacity(0.45))
                        .frame(width: 2, height: index == i ? 8 : 5)
                    if i < 12 { Spacer(minLength: 0) }
                }
            }
        }
    }
}

/// Popover content, Variant A (panel): header (icon + title + right-aligned
/// value) → slider + ticks → hint → divider → launch-at-login → divider →
/// deep link → centered Quit. Live values come from `DisplayOffModel`.
struct PopoverView: View {
    @Environment(DisplayOffModel.self) private var model
    @State private var launchAtLogin = false
    @State private var sliderIndex = 0
    @State private var showExpander = false
    @State private var isWriting = false
    @State private var writeError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.secondary)
                Text("不活跃时关闭显示器")
                    .font(.headline)
                Spacer()
                if let value = model.activeValue {
                    Text(displayOffStopLabel(value))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else if model.readFailed {
                    Text("无法读取")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("读取中…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            if model.readFailed {
                readFailureRow
            } else {
                DisplayOffSlider(index: $sliderIndex, disabled: model.isLoading || isWriting) {
                    commitMainSlider()
                }
                if let value = model.activeValue, !displayOffStops.contains(value) {
                    Text("系统设置中为其他值：\(displayOffStopLabel(value))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if model.hasBattery {
                    expanderRow
                }
                if let writeError {
                    Text(writeError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Text("修改需输入管理员密码")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Divider()
            Toggle("登录时启动", isOn: $launchAtLogin)
                .toggleStyle(.switch)
            Divider()
            Button("在系统设置中打开…") {
                openLockScreenSettings()
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            syncSliderToModel()
            Task { await model.read() }
        }
        .onChange(of: model.activeValue) {
            syncSliderToModel()
        }
        .onChange(of: model.readFailed) {
            if !model.readFailed { syncSliderToModel() }
        }
    }

    // MARK: - Subviews

    private var readFailureRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("无法读取当前设置")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("重试") {
                    Task { await model.read() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("在系统设置中打开…") {
                    openLockScreenSettings()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var expanderRow: some View {
        DisclosureGroup(isExpanded: $showExpander) {
            VStack(alignment: .leading, spacing: 10) {
                PerSourceSliderRow(
                    source: .battery,
                    value: model.values[.battery],
                    disabled: isWriting
                ) { minutes, snapBack in
                    commitWrite(minutes, source: .battery, snapBack: snapBack)
                }
                PerSourceSliderRow(
                    source: .ac,
                    value: model.values[.ac],
                    disabled: isWriting
                ) { minutes, snapBack in
                    commitWrite(minutes, source: .ac, snapBack: snapBack)
                }
            }
            .padding(.top, 4)
        } label: {
            Text("电池 / 电源适配器")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: showExpander) {
            // Re-read per-source values when a source becomes visible.
            if showExpander { Task { await model.read() } }
        }
    }

    // MARK: - Write flow

    private func commitMainSlider() {
        guard let current = model.activeValue else { return }
        let minutes = displayOffStops[sliderIndex]
        guard minutes != current else { return }
        commitWrite(minutes, source: model.activeSource) {
            sliderIndex = nearestStopIndex(for: current)
        }
    }

    private func commitWrite(
        _ minutes: Int,
        source: PowerSource,
        snapBack: @escaping () -> Void
    ) {
        guard !isWriting else { return }
        guard presentFirstWriteHintIfNeeded() else {
            snapBack()
            return
        }
        isWriting = true
        writeError = nil
        Task {
            let ok = await model.apply(minutes, to: source)
            isWriting = false
            if ok {
                model.values[source] = minutes
            } else {
                writeError = "写入失败（密码取消或未授权）"
                snapBack()
            }
        }
    }

    /// One-time first-write notice; returns false if the user cancels.
    private func presentFirstWriteHintIfNeeded() -> Bool {
        let key = "NeverSleep.writeHintShown"
        if UserDefaults.standard.bool(forKey: key) { return true }

        let alert = NSAlert()
        alert.messageText = "修改需输入管理员密码"
        alert.informativeText = "修改「不活跃时关闭显示器」需要管理员权限，每次修改会弹出系统密码确认框。"
        let checkbox = NSButton(checkboxWithTitle: "不再提示", target: nil, action: nil)
        alert.accessoryView = checkbox
        alert.addButton(withTitle: "继续")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if checkbox.state == .on {
            UserDefaults.standard.set(true, forKey: key)
        }
        return response == .alertFirstButtonReturn
    }

    // MARK: - Helpers

    private func syncSliderToModel() {
        if let value = model.activeValue {
            sliderIndex = nearestStopIndex(for: value)
        }
    }

    private func openLockScreenSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Lock-Screen-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// One slider per power source, shown in the expander on battery machines.
private struct PerSourceSliderRow: View {
    let source: PowerSource
    var value: Int?
    var disabled: Bool
    var onCommit: (Int, @escaping () -> Void) -> Void

    @State private var index = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(source == .battery ? "电池" : "电源适配器")
                    .font(.caption)
                Spacer()
                if let value {
                    Text(displayOffStopLabel(value))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Slider(
                value: Binding(
                    get: { Double(index) },
                    set: { index = Int($0.rounded()) }
                ),
                in: 0...12,
                step: 1,
                onEditingChanged: { editing in
                    if !editing, let value {
                        let minutes = displayOffStops[index]
                        guard minutes != value else { return }
                        onCommit(minutes) {
                            index = nearestStopIndex(for: value)
                        }
                    }
                }
            )
            .disabled(disabled)
            .controlSize(.small)
        }
        .onAppear {
            if let value { index = nearestStopIndex(for: value) }
        }
        .onChange(of: value) {
            if let value { index = nearestStopIndex(for: value) }
        }
    }
}

#Preview {
    PopoverView()
        .environment(DisplayOffModel())
}
