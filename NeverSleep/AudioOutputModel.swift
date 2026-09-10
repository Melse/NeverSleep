//
//  AudioOutputModel.swift
//  NeverSleep
//
//  Created by Melse on 2026/9/10.
//

import CoreAudio
import Foundation
import Observation

enum AudioTransportKind: String, Sendable {
    case builtIn
    case bluetooth
    case usb
    case airPlay
    case display
    case other
}

struct AudioDeviceFacts: Sendable, Equatable {
    var id: AudioObjectID
    var name: String
    var isAlive: Bool
    var isHidden: Bool
    var hasOutputStreams: Bool
    var canBeDefaultOutput: Bool
    var transport: AudioTransportKind
}

enum AudioOutputSetOutcome: Sendable, Equatable {
    case failed
    case alreadyCurrent
    case pendingConfirm
    case confirmed
}

enum AudioOutputSetAttempt: Sendable, Equatable {
    case failed
    case pendingConfirm
}

enum AudioOutputIdleName: Sendable, Equatable {
    case loading
    case empty
    case readFailed
    case named(String)
}

nonisolated func filterDefaultSelectableOutputs(_ devices: [AudioDeviceFacts]) -> [AudioDeviceFacts] {
    devices.filter {
        $0.isAlive && !$0.isHidden && $0.hasOutputStreams && $0.canBeDefaultOutput
    }
}

nonisolated func disambiguatedDisplayNames(_ devices: [AudioDeviceFacts]) -> [AudioObjectID: String] {
    var counts: [String: Int] = [:]
    for device in devices {
        counts[device.name, default: 0] += 1
    }
    var result: [AudioObjectID: String] = [:]
    for device in devices {
        if counts[device.name, default: 0] > 1 {
            result[device.id] = "\(device.name) (\(transportLabel(device.transport)))"
        } else {
            result[device.id] = device.name
        }
    }
    return result
}

nonisolated func transportLabel(_ transport: AudioTransportKind) -> String {
    switch transport {
    case .builtIn: return String(localized: "内置")
    case .bluetooth: return "Bluetooth"
    case .usb: return "USB"
    case .airPlay: return "AirPlay"
    case .display: return String(localized: "显示器")
    case .other: return String(localized: "其他")
    }
}

nonisolated func mapAudioOutputSetResult(status: OSStatus) -> AudioOutputSetAttempt {
    status == noErr ? .pendingConfirm : .failed
}

nonisolated func audioOutputIdleName(
    isLoading: Bool,
    devicesEmpty: Bool,
    currentName: String?
) -> AudioOutputIdleName {
    if isLoading { return .loading }
    if devicesEmpty { return .empty }
    if let currentName { return .named(currentName) }
    return .readFailed
}

struct AudioOutputDevice: Identifiable, Sendable, Equatable {
    var id: AudioObjectID
    var name: String
    var isCurrent: Bool
}

@Observable
final class AudioOutputModel {
    var devices: [AudioOutputDevice] = []
    var currentName: String?
    var isLoading = true
    var readFailed = false
    var writeError: String?
    var isSetting = false

    var idleName: AudioOutputIdleName {
        audioOutputIdleName(
            isLoading: isLoading,
            devicesEmpty: !isLoading && devices.isEmpty && !readFailed,
            currentName: currentName
        )
    }

    private var listenerTokens: [(address: AudioObjectPropertyAddress, block: AudioObjectPropertyListenerBlock)] = []
    private var confirmTask: Task<AudioOutputSetOutcome, Never>?
    private var isListening = false

    func refresh() {
        let snapshot = Self.loadSnapshot()
        apply(snapshot)
        isLoading = false
    }

    func startListening() {
        stopListening()
        if devices.isEmpty {
            isLoading = true
        }
        refresh()
        isListening = true
        addListener(selector: kAudioHardwarePropertyDevices)
        addListener(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    func stopListening() {
        confirmTask?.cancel()
        confirmTask = nil
        isListening = false
        let system = AudioObjectID(kAudioObjectSystemObject)
        for index in listenerTokens.indices {
            AudioObjectRemovePropertyListenerBlock(
                system,
                &listenerTokens[index].address,
                DispatchQueue.main,
                listenerTokens[index].block
            )
        }
        listenerTokens.removeAll()
    }

    func select(_ id: AudioObjectID) async -> AudioOutputSetOutcome {
        writeError = nil
        if let current = Self.defaultOutputID(), id == current {
            return .alreadyCurrent
        }
        isSetting = true
        defer { isSetting = false }

        switch mapAudioOutputSetResult(status: Self.setDefaultOutput(id)) {
        case .failed:
            writeError = String(localized: "切换失败")
            return .failed
        case .pendingConfirm:
            let confirmed = await waitForDefault(id)
            switch confirmed {
            case .confirmed:
                refresh()
                return .confirmed
            case .failed:
                writeError = String(localized: "切换失败")
                refresh()
                return .failed
            case .pendingConfirm:
                return .pendingConfirm
            case .alreadyCurrent:
                return .failed
            }
        }
    }

    private func waitForDefault(_ id: AudioObjectID) async -> AudioOutputSetOutcome {
        confirmTask?.cancel()
        let task = Task { () -> AudioOutputSetOutcome in
            let deadline = Date().addingTimeInterval(8)
            while Date() < deadline {
                if Task.isCancelled { return .pendingConfirm }
                if Self.defaultOutputID() == id { return .confirmed }
                try? await Task.sleep(for: .milliseconds(100))
            }
            return .failed
        }
        confirmTask = task
        return await task.value
    }

    private func apply(_ snapshot: HALSnapshot) {
        readFailed = snapshot.currentNameMissing && !snapshot.devices.isEmpty
        let names = disambiguatedDisplayNames(snapshot.devices)
        let currentID = snapshot.currentID
        devices = snapshot.devices.map { facts in
            AudioOutputDevice(
                id: facts.id,
                name: names[facts.id] ?? facts.name,
                isCurrent: facts.id == currentID
            )
        }
        if let currentID, let match = devices.first(where: { $0.id == currentID }) {
            currentName = match.name
        } else if snapshot.devices.isEmpty {
            currentName = nil
        } else {
            currentName = snapshot.currentName
        }
    }

    private func addListener(selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self, self.isListening else { return }
                self.refresh()
            }
        }
        let system = AudioObjectID(kAudioObjectSystemObject)
        let status = AudioObjectAddPropertyListenerBlock(system, &address, DispatchQueue.main, block)
        if status == noErr {
            listenerTokens.append((address, block))
        }
    }

    private struct HALSnapshot {
        var devices: [AudioDeviceFacts]
        var currentID: AudioObjectID?
        var currentName: String?
        var currentNameMissing: Bool
    }

    private static func loadSnapshot() -> HALSnapshot {
        let raw = allDeviceIDs().map(facts(for:))
        let filtered = filterDefaultSelectableOutputs(raw)
        let currentID = defaultOutputID()
        let currentName = currentID.flatMap { id in
            filtered.first(where: { $0.id == id })?.name ?? name(of: id)
        }
        let currentNameMissing = currentID != nil && currentName == nil
        return HALSnapshot(
            devices: filtered,
            currentID: currentID,
            currentName: currentName,
            currentNameMissing: currentNameMissing
        )
    }

    private static func allDeviceIDs() -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else {
            return []
        }
        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        let status = AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids)
        return status == noErr ? ids : []
    }

    private static func facts(for id: AudioObjectID) -> AudioDeviceFacts {
        AudioDeviceFacts(
            id: id,
            name: name(of: id) ?? "",
            isAlive: boolProperty(id, kAudioDevicePropertyDeviceIsAlive, scope: kAudioObjectPropertyScopeGlobal),
            isHidden: boolProperty(id, kAudioDevicePropertyIsHidden, scope: kAudioObjectPropertyScopeGlobal),
            hasOutputStreams: streamCount(id, scope: kAudioObjectPropertyScopeOutput) > 0,
            canBeDefaultOutput: boolProperty(
                id,
                kAudioDevicePropertyDeviceCanBeDefaultDevice,
                scope: kAudioObjectPropertyScopeOutput
            ),
            transport: transportKind(of: id)
        )
    }

    private static func defaultOutputID() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioObjectID()
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &id
        )
        return status == noErr && id != kAudioObjectUnknown ? id : nil
    }

    private static func setDefaultOutput(_ id: AudioObjectID) -> OSStatus {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = id
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &value
        )
    }

    private static func name(of id: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var cfName: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &cfName) { pointer in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let cfName else { return nil }
        return cfName.takeRetainedValue() as String
    }

    private static func boolProperty(
        _ id: AudioObjectID,
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        return status == noErr && value != 0
    }

    private static func streamCount(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr else { return 0 }
        return Int(size) / MemoryLayout<AudioObjectID>.size
    }

    private static func transportKind(of id: AudioObjectID) -> AudioTransportKind {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value)
        guard status == noErr else { return .other }
        switch value {
        case kAudioDeviceTransportTypeBuiltIn: return .builtIn
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return .bluetooth
        case kAudioDeviceTransportTypeUSB: return .usb
        case kAudioDeviceTransportTypeAirPlay: return .airPlay
        case kAudioDeviceTransportTypeDisplayPort, kAudioDeviceTransportTypeHDMI: return .display
        default: return .other
        }
    }
}
