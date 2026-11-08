import Testing
@testable import Puls

struct HeartZonesTests {
    @Test func maxHRFromAHATable() {
        #expect(HeartZones.maxHR(age: 40) == 180)
        #expect(HeartZones.maxHR(age: 43) == 175)   // nærmeste gruppe: 45
        #expect(HeartZones.maxHR(age: 25) == 200)   // lige langt fra 20 og 30 → 20
        #expect(HeartZones.maxHR(age: 15) == 200)
        #expect(HeartZones.maxHR(age: 85) == 150)
    }

    @Test func ageBasedBoundaries() {
        let z = HeartZones(age: 40)   // maks 180: moderat 90–126, hård fra 126
        #expect(z.zone(for: 80) == .light)
        #expect(z.zone(for: 90) == .moderate)
        #expect(z.zone(for: 125) == .moderate)
        #expect(z.zone(for: 127) == .vigorous)
        #expect(z.zone(for: 200) == .vigorous)          // hård har intet loft
        #expect(z.bpmRange(.vigorous).upperBound == .infinity)
        #expect(abs(z.maxHR - 180) < 0.001)
    }

    @Test func manualBoundaries() {
        let z = HeartZones(moderate: 100, vigorous: 130)
        #expect(z.zone(for: 99) == .light)
        #expect(z.zone(for: 100) == .moderate)
        #expect(z.zone(for: 130) == .vigorous)
        #expect(z.bpmRange(.moderate) == 100...130)
        #expect(abs(z.maxHR - 130 / 0.7) < 0.001)
    }
}
