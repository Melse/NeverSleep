//
//  PopoverLayoutPrototype.swift
//  PROTOTYPE — throwaway UI variants for the NeverSleep popover.
//  Switch with ←/→ arrow keys or the bottom bar. See wayfinder ticket
//  "Popover layout prototype" (#7). Not production code.
//

import SwiftUI

// MARK: - Stops (decided: 13 equidistant stops, Never leftmost)

let prototypeStops: [Int] = [0, 1, 2, 3, 5, 10, 20, 30, 60, 90, 120, 150, 180]

func prototypeStopLabel(_ minutes: Int) -> String {
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
struct PrototypeSlider: View {
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

// MARK: - Variant A: Panel (title header, slider, hint, toggle, deep link, Quit)

struct PopoverVariantA: View {
    @State private var index = 7 // 30 分钟

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.secondary)
                Text("不活跃时关闭显示器")
                    .font(.headline)
                Spacer()
                Text(prototypeStopLabel(prototypeStops[index]))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            PrototypeSlider(index: $index)
            Text("修改需输入管理员密码")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Divider()
            Toggle("登录时启动", isOn: .constant(false))
                .toggleStyle(.switch)
            Divider()
            Button("在系统设置中打开…") {}
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("退出", role: .destructive) {}
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .frame(width: 280)
    }
}

// MARK: - Variant B: Menu (compact rows, menu-style separators, dense)

struct PopoverVariantB: View {
    @State private var index = 7

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("显示器关闭时间")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(prototypeStopLabel(prototypeStops[index]))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            PrototypeSlider(index: $index)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            Divider()

            Toggle("登录时启动", isOn: .constant(false))
                .toggleStyle(.switch)
                .font(.callout)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

            Divider()

            Button {} label: {
                Label("在系统设置中打开…", systemImage: "arrow.up.forward.app")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Divider()

            Button {} label: {
                Label("退出", systemImage: "power")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(width: 250)
    }
}

// MARK: - Variant C: Zones (grouped sections, wider, section headers)

struct PopoverVariantC: View {
    @State private var index = 7

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("关闭显示器")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text("不活跃时关闭显示器")
                        .font(.body)
                    Spacer()
                    Text(prototypeStopLabel(prototypeStops[index]))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                }
                PrototypeSlider(index: $index)
                Text("拖动后需输入管理员密码")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("设置")
                    .font(.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Toggle("登录时启动", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .font(.callout)
                Button("在系统设置中打开…") {}
                    .buttonStyle(.plain)
                    .font(.callout)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            Button("退出", role: .destructive) {}
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(14)
        .frame(width: 300)
    }
}

// MARK: - Switcher

enum PrototypeVariant: String, CaseIterable {
    case a = "A · 面板"
    case b = "B · 菜单"
    case c = "C · 分区"
}

struct PopoverLayoutPrototype: View {
    @State private var variant = PrototypeVariant.a

    var body: some View {
        ZStack {
            switch variant {
            case .a: PopoverVariantA()
            case .b: PopoverVariantB()
            case .c: PopoverVariantC()
            }
            VStack {
                Spacer()
                PrototypeSwitcherBar(variant: $variant)
            }
        }
        .frame(minWidth: 520, minHeight: 480)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) {
            cycle(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            cycle(1)
            return .handled
        }
    }

    private func cycle(_ delta: Int) {
        let all = PrototypeVariant.allCases
        guard let cur = all.firstIndex(of: variant) else { return }
        variant = all[(cur + delta + all.count) % all.count]
    }
}

struct PrototypeSwitcherBar: View {
    @Binding var variant: PrototypeVariant

    var body: some View {
        HStack(spacing: 12) {
            Button("‹") { cycle(-1) }
            Text("原型 \(variant.rawValue)")
                .font(.caption.monospaced())
            Button("›") { cycle(1) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(.secondary.opacity(0.3)))
        .padding(.bottom, 12)
    }

    private func cycle(_ delta: Int) {
        let all = PrototypeVariant.allCases
        guard let cur = all.firstIndex(of: variant) else { return }
        variant = all[(cur + delta + all.count) % all.count]
    }
}

#Preview {
    PopoverLayoutPrototype()
}
