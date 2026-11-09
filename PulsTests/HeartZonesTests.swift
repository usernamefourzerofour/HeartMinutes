import Foundation
import Testing
@testable import Puls

struct HeartZonesTests {
    @Test func maxHRIs220MinusAge() {
        #expect(HeartZones.maxHR(age: 40) == 180)
        #expect(HeartZones.maxHR(age: 36) == 184)
        #expect(HeartZones.maxHR(age: 20) == 200)
    }

    @Test func twoZonesFollowAHA() {
        let z = HeartZones(age: 40)   // maks 180: moderat fra 90, hård fra 126
        #expect(z.count == 3)
        #expect(z.zone(for: 80) == 0)
        #expect(z.zone(for: 90) == 1)
        #expect(z.zone(for: 125) == 1)
        #expect(z.zone(for: 127) == 2)
        #expect(z.zone(for: 200) == 2)              // øverste zone har intet loft
        #expect(z.bpmRange(2).upperBound == .infinity)
        #expect(z.weights == [0, 1, 2])
        #expect(abs(z.maxHR - 180) < 0.001)
    }

    @Test func fiveZonesAreTheCommonOnes() {
        let z = HeartZones(maxHR: 200, model: .five)
        #expect(z.count == 6)                            // Z0 + Z1–Z5
        #expect(z.thresholds == [100, 120, 140, 160, 180])   // 50/60/70/80/90 %
        #expect(z.zone(for: 90) == 0)                    // Z0: under 50 %
        #expect(z.zone(for: 110) == 1)                   // Z1
        #expect(z.zone(for: 150) == 3)                   // Z3
        #expect(z.zone(for: 195) == 5)                   // Z5
        #expect(z.weights == [0, 0, 1, 2, 2, 2])
    }

    @Test func fixedBoundaries() {
        let z = HeartZones(moderate: 100, vigorous: 130)
        #expect(z.zone(for: 99) == 0)
        #expect(z.zone(for: 100) == 1)
        #expect(z.zone(for: 130) == 2)
        #expect(abs(z.bpmRange(1).lowerBound - 100) < 0.001)
        #expect(abs(z.bpmRange(1).upperBound - 130) < 0.001)
        #expect(abs(z.maxHR - 130 / 0.7) < 0.001)
    }

    @Test func fiveZoneWeightsAreUsed() {
        // 10 min konstant i Z4 (× 2) = 20 Heart Minutes; i Z1 (× 0) = 0.
        let t0 = Date(timeIntervalSince1970: 0)
        let z = HeartZones(maxHR: 200, model: .five)
        func run(_ bpm: Double) -> Double {
            let s = (0...10).map { HRSample(date: t0.addingTimeInterval(Double($0) * 60), bpm: bpm) }
            return ActiveMinutes(s, config: .init(zones: z, requireActive: false)).total
        }
        #expect(abs(run(170) - 20) < 0.001)
        #expect(run(100) == 0)
    }
}
