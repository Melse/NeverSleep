//
//  AudioOutputModelTests.swift
//  NeverSleepTests
//
//  Created by Melse on 2026/9/10.
//

import Testing
@testable import NeverSleep

struct AudioOutputModelTests {

    @Test func filterDropsInputOnlyDevices() {
        let inputOnly = AudioDeviceFacts(
            id: 1,
            name: "Mic",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: false,
            canBeDefaultOutput: false,
            transport: .builtIn
        )
        #expect(filterDefaultSelectableOutputs([inputOnly]).isEmpty)
    }

    @Test func filterKeepsOutputCapableAmongMixed() {
        let mic = AudioDeviceFacts(
            id: 1,
            name: "Mic",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: false,
            canBeDefaultOutput: false,
            transport: .builtIn
        )
        let speakers = AudioDeviceFacts(
            id: 2,
            name: "Speakers",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: true,
            transport: .builtIn
        )
        let kept = filterDefaultSelectableOutputs([mic, speakers])
        #expect(kept.map(\.id) == [2])
    }

    @Test func filterDropsHiddenAndNonDefaultableOutputs() {
        let hidden = AudioDeviceFacts(
            id: 3,
            name: "Hidden Out",
            isAlive: true,
            isHidden: true,
            hasOutputStreams: true,
            canBeDefaultOutput: true,
            transport: .usb
        )
        let notDefaultable = AudioDeviceFacts(
            id: 4,
            name: "Aggregate",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: false,
            transport: .other
        )
        #expect(filterDefaultSelectableOutputs([hidden, notDefaultable]).isEmpty)
    }

    @Test func filterKeepsAirPlayOnlyWhenDefaultable() {
        let airPlay = AudioDeviceFacts(
            id: 5,
            name: "Living Room",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: true,
            transport: .airPlay
        )
        let browseOnly = AudioDeviceFacts(
            id: 6,
            name: "Kitchen",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: false,
            transport: .airPlay
        )
        let kept = filterDefaultSelectableOutputs([airPlay, browseOnly])
        #expect(kept.map(\.id) == [5])
    }

    @Test func duplicateNamesAppendTransport() {
        let bluetooth = AudioDeviceFacts(
            id: 10,
            name: "USB Audio",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: true,
            transport: .bluetooth
        )
        let usb = AudioDeviceFacts(
            id: 11,
            name: "USB Audio",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: true,
            transport: .usb
        )
        let names = disambiguatedDisplayNames([bluetooth, usb])
        #expect(names[10] != names[11])
        #expect(names[10]?.contains("USB Audio") == true)
        #expect(names[11]?.contains("USB Audio") == true)
    }

    @Test func uniqueNamesStayUnsuffixed() {
        let speakers = AudioDeviceFacts(
            id: 2,
            name: "Mac mini Speakers",
            isAlive: true,
            isHidden: false,
            hasOutputStreams: true,
            canBeDefaultOutput: true,
            transport: .builtIn
        )
        let names = disambiguatedDisplayNames([speakers])
        #expect(names[2] == "Mac mini Speakers")
    }

    @Test func setResultMapperTreatsNonZeroAsFailure() {
        let result = mapAudioOutputSetResult(status: 1, chosenID: 2, currentID: 1)
        #expect(result == .failed)
    }

    @Test func setResultMapperTreatsAlreadyCurrentAsConfirmed() {
        let result = mapAudioOutputSetResult(status: 0, chosenID: 7, currentID: 7)
        #expect(result == .alreadyCurrent)
    }

    @Test func setResultMapperTreatsZeroStatusAsPendingConfirm() {
        let result = mapAudioOutputSetResult(status: 0, chosenID: 8, currentID: 7)
        #expect(result == .pendingConfirm)
    }

    @Test func idleNameTokensAreDistinctFromDeviceName() {
        #expect(audioOutputIdleName(isLoading: true, devicesEmpty: false, currentName: nil) == .loading)
        #expect(audioOutputIdleName(isLoading: false, devicesEmpty: true, currentName: nil) == .empty)
        #expect(audioOutputIdleName(isLoading: false, devicesEmpty: false, currentName: nil) == .readFailed)
        #expect(audioOutputIdleName(isLoading: false, devicesEmpty: false, currentName: "Speakers") == .named("Speakers"))
    }
}
