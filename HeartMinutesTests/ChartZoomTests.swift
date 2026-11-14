import Testing
@testable import HeartMinutes

@MainActor
struct ChartZoomTests {
    @Test func defaultFollowsData() {
        #expect(HeartChart.yDomain([60, 100], maxHR: 180, zoomOut: 0) == 55...105)
    }

    @Test func fullZoomOutIsZeroToMaxHR() {
        #expect(HeartChart.yDomain([60, 100], maxHR: 180, zoomOut: 1) == 0...180)
    }

    @Test func halfwayInterpolates() {
        #expect(HeartChart.yDomain([60, 100], maxHR: 180, zoomOut: 0.5) == 27.5...142.5)
    }

    @Test func dataAboveMaxHRStaysVisible() {
        #expect(HeartChart.yDomain([150, 190], maxHR: 180, zoomOut: 1) == 0...195)
    }
}
