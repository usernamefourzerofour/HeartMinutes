import Testing
import Foundation
@testable import HeartMinutes

/// The sample week for App Store screenshots (`-DemoData YES`).
struct DemoDataTests {
    let calendar = Calendar(identifier: .gregorian)
    /// Monday 2 Nov 2026 – Monday 9 Nov 2026.
    var week: DateInterval {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        return DateInterval(start: start, end: calendar.date(byAdding: .day, value: 7, to: start)!)
    }

    func heartMinutes(_ demo: DemoData.Content) -> Double {
        let marked = HRSample.markingExercise(HRSample.markingWorkouts(demo.samples, demo.workouts.map(\.interval)),
                                              demo.exercise)
        let config = ActiveMinutes.Config(zones: HeartZones(age: 40), requireActive: true)
        return ActiveMinutes(marked, config: config).points.last?.total ?? 0
    }

    @Test func aWholeWeekIsAboveTheGoal() {
        let demo = DemoData.period(week, now: week.end, calendar: calendar)
        #expect(demo.workouts.count == 2)
        #expect((160...240).contains(heartMinutes(demo)))
    }

    @Test func nothingInTheFuture() {
        let now = week.start.addingTimeInterval(3.5 * 86_400)   // Thursday at noon
        let demo = DemoData.period(week, now: now, calendar: calendar)
        #expect(demo.samples.allSatisfy { $0.date <= now })
        #expect(demo.workouts.allSatisfy { $0.interval.end <= now })
        // Monday's run and the walks on Monday, Tuesday and Wednesday are done.
        #expect((80...160).contains(heartMinutes(demo)))
    }

    @Test func theSameDayGivesTheSameValues() {
        let a = DemoData.period(week, now: week.end, calendar: calendar).samples.map(\.bpm)
        let b = DemoData.period(week, now: week.end, calendar: calendar).samples.map(\.bpm)
        #expect(a == b)
    }
}
