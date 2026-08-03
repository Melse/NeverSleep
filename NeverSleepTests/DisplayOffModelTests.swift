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
        // 7 → 5 (index 4); 12 → 10 (index 5); 0 → Never (index 0); 180 → index 12
        #expect(nearestStopIndex(for: 7) == 4)
        #expect(nearestStopIndex(for: 12) == 5)
        #expect(nearestStopIndex(for: 0) == 0)
        #expect(nearestStopIndex(for: 180) == 12)
        // exact stops map to themselves
        #expect(nearestStopIndex(for: 30) == 7)
        #expect(nearestStopIndex(for: 90) == 9)
    }

    @Test func nearestStopIndexTieBreaksDown() {
        // 4 is equidistant from 3 (idx 3) and 5 (idx 4) → lower wins
        #expect(nearestStopIndex(for: 4) == 3)
    }
}
