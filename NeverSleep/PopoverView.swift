//
//  PopoverView.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

import SwiftUI

/// The 13 system stops, left→right: Never(0) … 180 minutes. Equidistant on track.
let displayOffStops: [Int] = [0, 1, 2, 3, 5, 10, 20, 30, 60, 90, 120, 150, 180]

/// System-aligned wording for a stop value. Full localization lands in
/// Build: localization and verification checklist.
func displayOffStopLabel(_ minutes: Int) -> String {
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

/// Popover content, Variant A (panel) from the layout prototype review:
/// header (icon + title + right-aligned value) → slider + ticks → hint →
/// divider → launch-at-login → divider → deep link → centered Quit.
struct PopoverView: View {
    @State private var sliderIndex = 7 // 30 分钟 placeholder; real value in read-path ticket
    @State private var launchAtLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.secondary)
                Text("不活跃时关闭显示器")
                    .font(.headline)
                Spacer()
                Text(displayOffStopLabel(displayOffStops[sliderIndex]))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            DisplayOffSlider(index: $sliderIndex)
            Text("修改需输入管理员密码")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Divider()
            Toggle("登录时启动", isOn: $launchAtLogin)
                .toggleStyle(.switch)
            Divider()
            Button("在系统设置中打开…") {
                // No-op for now; wired in the write-path ticket.
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
        .frame(width: 280)
    }
}

#Preview {
    PopoverView()
}
