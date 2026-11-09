import Testing
import Foundation
@testable import Puls

/// Et lavere tal fra en afbrudt baggrundsopdatering må ikke overskrive det gemte tal.
struct ComplicationStoreTests {
    let now = Date.now
    func data(_ minutes: Double, updated: Date) -> ComplicationData {
        ComplicationData(minutes: minutes, goal: 150, updated: updated)
    }

    @Test func zeroInBackgroundDoesNotOverwriteSamePeriod() {
        let old = data(42, updated: now.addingTimeInterval(-60))
        #expect(!ComplicationStore.shouldReplace(old, with: data(0, updated: now), for: .today,
                                                 allowDecrease: false, now: now))
    }

    @Test func higherValueInBackgroundIsSaved() {
        let old = data(42, updated: now.addingTimeInterval(-60))
        #expect(ComplicationStore.shouldReplace(old, with: data(50, updated: now), for: .today,
                                                allowDecrease: false, now: now))
    }

    @Test func appOpenMayDecrease() {
        // Fx efter ændrede indstillinger.
        let old = data(42, updated: now.addingTimeInterval(-60))
        #expect(ComplicationStore.shouldReplace(old, with: data(10, updated: now), for: .today,
                                                allowDecrease: true, now: now))
    }

    @Test func newPeriodStartsOver() {
        // Gemt i går: i dag må gerne starte forfra på 0.
        let old = data(42, updated: now.addingTimeInterval(-2 * 86_400))
        #expect(ComplicationStore.shouldReplace(old, with: data(0, updated: now), for: .today,
                                                allowDecrease: false, now: now))
    }

    @Test func rollingPeriodMayDecrease() {
        let old = data(42, updated: now.addingTimeInterval(-60))
        #expect(ComplicationStore.shouldReplace(old, with: data(30, updated: now), for: .last7Days,
                                                allowDecrease: false, now: now))
    }

    @Test func nothingStoredIsSaved() {
        #expect(ComplicationStore.shouldReplace(nil, with: data(0, updated: now), for: .thisWeek,
                                                allowDecrease: false, now: now))
    }
}
