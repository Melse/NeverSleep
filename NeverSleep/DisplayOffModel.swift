//
//  DisplayOffModel.swift
//  NeverSleep
//
//  Created by Melse on 2026/8/3.
//

import Foundation
import IOKit.ps
import Observation

/// Power source the display-off interval is configured per-source for.
enum PowerSource: String, CaseIterable, Sendable {
    case battery
    case ac

    var pmsetSection: String {
        switch self {
        case .battery: return "Battery Power"
        case .ac: return "AC Power"
        }
    }
}

/// Parse `pmset -g custom` output into per-source `displaysleep` minutes.
/// Pure function — kept testable. Unknown sections and malformed lines are
/// skipped; an empty dict means nothing usable was found.
nonisolated func parsePmsetCustom(_ text: String) -> [PowerSource: Int] {
    var result: [PowerSource: Int] = [:]
    var currentSection: PowerSource?

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if let section = powerSourceFromSectionHeader(line) {
            currentSection = section
            continue
        }
        guard let section = currentSection else { continue }
        // `displaysleep 60` (or `displaysleep         60`)
        let parts = line.split(whereSeparator: \.isWhitespace)
        guard parts.count == 2, parts[0] == "displaysleep", let minutes = Int(parts[1]) else {
            continue
        }
        result[section] = minutes
    }
    return result
}

private nonisolated func powerSourceFromSectionHeader(_ line: String) -> PowerSource? {
    switch line {
    case "Battery Power:", "Battery Power :": return .battery
    case "AC Power:", "AC Power :": return .ac
    default: return nil
    }
}

/// Nearest stop index (0…12) for a display-off value in minutes.
nonisolated func nearestStopIndex(for minutes: Int, stops: [Int] = displayOffStops) -> Int {
    var best = 0
    var bestDistance = Int.max
    for (i, stop) in stops.enumerated() {
        let distance = abs(stop - minutes)
        if distance < bestDistance {
            bestDistance = distance
            best = i
        }
    }
    return best
}

/// Observable read model. Reads via `/usr/bin/pmset -g custom` (sandbox-safe,
/// no root), detects the active source with IOPowerSources.
@Observable
final class DisplayOffModel {
    var values: [PowerSource: Int] = [:] {
        didSet {
            // Battery section present ⇔ machine is a portable; drives the expander.
            hasBattery = values[.battery] != nil
        }
    }
    var activeSource: PowerSource = .ac
    var hasBattery = false
    var readFailed = false
    var isLoading = false

    /// Menu bar short label: active source value, number only (「—」 when unknown).
    var menuBarText: String {
        guard let value = activeValue else { return "—" }
        return String(value)
    }

    /// Active source's display-off value in minutes (nil when unknown/failed).
    var activeValue: Int? {
        values[activeSource]
    }

    func read() async {
        isLoading = true
        defer { isLoading = false }

        let source = await Self.currentPowerSource()
        let parsed = await Self.pmsetCustomOutput()

        switch parsed {
        case .success(let sections):
            readFailed = false
            values = sections
            activeSource = source
        case .failure:
            readFailed = true
        }
    }

    // MARK: - Internals

    private static func currentPowerSource() async -> PowerSource {
        await Task.detached(priority: .userInitiated) {
            let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
            if let cfType = IOPSGetProvidingPowerSourceType(snapshot),
               let type = cfType.takeRetainedValue() as String? {
                if type == (kIOPMBatteryPowerKey as String) { return PowerSource.battery }
                // UPS treated as AC for v1 (no UPS machines in scope).
            }
            return .ac
        }.value
    }

    private static func pmsetCustomOutput() async -> Result<[PowerSource: Int], Error> {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            process.arguments = ["-g", "custom"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                return .failure(error)
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8)
            else {
                return .failure(PMSetError.nonZeroExit(process.terminationStatus))
            }

            let parsed = parsePmsetCustom(text)
            guard !parsed.isEmpty else {
                return .failure(PMSetError.unparseableOutput)
            }
            return .success(parsed)
        }.value
    }
}

enum PMSetError: Error {
    case nonZeroExit(Int32)
    case unparseableOutput
}
