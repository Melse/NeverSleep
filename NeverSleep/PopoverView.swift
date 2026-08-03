//
//  PopoverView.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

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
struct DisplayOffSlider: View {
    @Binding var index: Int
    var disabled = false

    var body: some View {
        VStack(spacing: 5) {
            Slider(
                value: Binding(
                    get: { Double(index) },
                    set: { index = Int($0.rounded()) }
                ),
                in: 0...12,
                step: 1
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

    var body: some View {
        @Bindable var model = model
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
                DisplayOffSlider(index: $sliderIndex, disabled: model.isLoading)
                if let value = model.activeValue, !displayOffStops.contains(value) {
                    Text("系统设置中为其他值：\(displayOffStopLabel(value))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if model.hasBattery {
                    expanderRow
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
            VStack(alignment: .leading, spacing: 8) {
                perSourceRow(.battery)
                perSourceRow(.ac)
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

    private func perSourceRow(_ source: PowerSource) -> some View {
        HStack {
            Text(source == .battery ? "电池" : "电源适配器")
                .font(.caption)
            Spacer()
            if let value = model.values[source] {
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

#Preview {
    PopoverView()
        .environment(DisplayOffModel())
}
