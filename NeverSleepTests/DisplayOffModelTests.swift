//
//  DisplayOffModelTests.swift
//  NeverSleepTests
//
//  Created by Melse on 2026/8/3.
//

import Testing
@testable import NeverSleep

struct DisplayOffModelTests {

    @Test func parsesACSection() {
        let output = """
        AC Power:
         Sleep On Power Button 1
         displaysleep         60
         disksleep            10
        """
        let parsed = parsePmsetCustom(output)
        #expect(parsed == [.ac: 60])
    }

    @Test func parsesBatteryAndAC() {
        let output = """
        Battery Power:
         displaysleep         5
        AC Power:
         displaysleep         30
        """
        let parsed = parsePmsetCustom(output)
        #expect(parsed == [.battery: 5, .ac: 30])
    }

    @Test func ignoresUnknownSections() {
        let output = """
        UPS Power:
         displaysleep         7
        SomeOtherSection:
         displaysleep         9
        """
        #expect(parsePmsetCustom(output).isEmpty)
    }

    @Test func neverIsZero() {
        let output = """
        AC Power:
         displaysleep         0
        """
        #expect(parsePmsetCustom(output) == [.ac: 0])
    }

    @Test func malformedLinesAreSkipped() {
        let output = """
        AC Power:
         displaysleep         notanumber
         displaysleep
        """
        #expect(parsePmsetCustom(output).isEmpty)
    }

    @Test func nearestStopIndexSnaps() {
        // Stops: Never(0), 1, 30, 60 → indexes 0…3
        // 7 → 1 (index 1); 0 → Never (index 0); 180 → 60 (index 3)
        #expect(nearestStopIndex(for: 7) == 1)
        #expect(nearestStopIndex(for: 0) == 0)
        #expect(nearestStopIndex(for: 180) == 3)
        // exact stops map to themselves
        #expect(nearestStopIndex(for: 1) == 1)
        #expect(nearestStopIndex(for: 30) == 2)
        #expect(nearestStopIndex(for: 60) == 3)
    }

    @Test func nearestStopIndexTieBreaksDown() {
        // 45 is equidistant from 30 (idx 2) and 60 (idx 3) → lower wins
        #expect(nearestStopIndex(for: 45) == 2)
    }
}
