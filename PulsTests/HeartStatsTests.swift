import Testing
import Foundation
@testable import Puls

struct HeartStatsTests {
    @Test func emptyGivesNil() { #expect(HeartStats([]) == nil) }

    @Test func computesMinAvgMax() {
        let s = [60.0, 90, 120].map { HRSample(date: .now, bpm: $0) }
        #expect(HeartStats(s) == HeartStats(min: 60, avg: 90, max: 120))
    }

    @Test func samplingRate() {
        let t0 = Date(timeIntervalSince1970: 0)
        let s = (0..<11).map { HRSample(date: t0.addingTimeInterval(Double($0) * 5), bpm: 70) }
        #expect(s.samplingRateHz == 0.2)          // 10 intervaller over 50 s
        #expect([HRSample]().samplingRateHz == nil)
        #expect(Array(s.prefix(1)).samplingRateHz == nil)
    }
}

struct SliceTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func sliceUsesInclusiveBounds() {
        let s = (0..<10).map { HRSample(date: t0.addingTimeInterval(Double($0) * 60), bpm: Double($0)) }
        let slice = s.slice(from: t0.addingTimeInterval(120), to: t0.addingTimeInterval(300))
        #expect(slice.map(\.bpm) == [2, 3, 4, 5])
        #expect(s.slice(from: t0.addingTimeInterval(10_000), to: t0.addingTimeInterval(20_000)).isEmpty)
        #expect(s.slice(from: t0.addingTimeInterval(-60), to: t0).map(\.bpm) == [0])
        #expect(slice.samplingRateHz == 3.0 / 180)
    }
}
