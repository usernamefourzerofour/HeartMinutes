import Testing
import Foundation
@testable import Puls

struct PeriodTests {
    var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return c
    }
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func thisWeekIsTheWholeWeek() {
        // Lørdag 7. nov. 2026 kl. 12 → mandag 2. nov. 00:00 til mandag 9. nov. 00:00 (hele ugen)
        let i = Period.thisWeek(now: date(2026, 11, 7, 12), calendar: cal)
        #expect(i.start == date(2026, 11, 2))
        #expect(i.end == date(2026, 11, 9))
        #expect(Period.isWeekLike(i, calendar: cal))
    }

    @Test func weekArrowsJumpWholeWeeks() {
        let now = date(2026, 11, 7, 12)
        let thisWeek = Period.thisWeek(now: now, calendar: cal)
        let prev = Period.shifted(thisWeek, by: -1, calendar: cal, now: now)
        #expect(prev.start == date(2026, 10, 26))
        #expect(prev.end == date(2026, 11, 2))          // hele forrige uge
        let back = Period.shifted(prev, by: 1, calendar: cal, now: now)
        #expect(back == thisWeek)                        // tilbage til hele denne uge
    }

    @Test func singleMondayIsADayNotAWeek() {
        let monday = DateInterval(start: date(2026, 11, 2), end: date(2026, 11, 3))
        #expect(!Period.isWeekLike(monday, calendar: cal))
        #expect(Period.shifted(monday, by: 1, calendar: cal).start == date(2026, 11, 3))
    }

    @Test func defaultIsWholeDay() {
        let i = Period.day(containing: date(2026, 11, 7, 12), calendar: cal)
        #expect(i.start == date(2026, 11, 7))
        #expect(i.end == date(2026, 11, 8))
        #expect(Period.wholeDays(i, calendar: cal) == 1)
    }

    @Test func shiftsWholeDaysAcrossDST() {
        // Sommertid slutter 25. okt. 2026 i Danmark: dagen er 25 timer.
        let i = DateInterval(start: date(2026, 10, 26), end: date(2026, 10, 27))
        let prev = Period.shifted(i, by: -1, calendar: cal)
        #expect(prev.start == date(2026, 10, 25))
        #expect(prev.end == date(2026, 10, 26))
    }

    @Test func shiftsMultiDayAndCustomPeriods() {
        let week = DateInterval(start: date(2026, 11, 1), end: date(2026, 11, 8))
        #expect(Period.shifted(week, by: 1, calendar: cal).start == date(2026, 11, 8))

        let custom = DateInterval(start: date(2026, 11, 7, 8), end: date(2026, 11, 7, 11))
        let next = Period.shifted(custom, by: 1, calendar: cal)
        #expect(next.start == date(2026, 11, 7, 11))
        #expect(next.end == date(2026, 11, 7, 14))
        #expect(Period.wholeDays(custom, calendar: cal) == nil)
    }
}

@MainActor
struct WorkoutMarkingTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func marksSamplesInsideWorkouts() {
        let s = (0..<6).map { HRSample(date: t0.addingTimeInterval(Double($0) * 60), bpm: 70) }
        let w = [DateInterval(start: t0.addingTimeInterval(120), end: t0.addingTimeInterval(240))]
        let marked = HRSample.markingWorkouts(s, w)
        #expect(marked.map(\.inWorkout) == [false, false, true, true, true, false])
        #expect(HRSample.segments(marked) == [0, 0, 1, 1, 1, 2])
    }

    @Test func thinningKeepsAtMostMax() {
        let s = (0..<4000).map { HRSample(date: t0.addingTimeInterval(Double($0)), bpm: 70) }
        let (drawn, step) = HeartChart.thinned(s, max: 1500)
        #expect(step == 3)
        #expect(drawn.count <= 1500)
        #expect(HeartChart.thinned(Array(s.prefix(100)), max: 1500).1 == 1)
    }

    @Test func nearestSample() {
        let s = (0..<5).map { HRSample(date: t0.addingTimeInterval(Double($0) * 60), bpm: Double(60 + $0)) }
        #expect(HeartChart.nearest(to: t0.addingTimeInterval(100), in: s)?.bpm == 62)
        #expect(HeartChart.nearest(to: t0, in: []) == nil)
    }
}

@MainActor
struct SampleFilterTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func filtersByType() {
        var w = HRSample(date: t0.addingTimeInterval(60), bpm: 120); w.inWorkout = true
        let s = [HRSample(date: t0, bpm: 60), w]
        #expect(HRSample.filtered(s, background: true, workouts: true).count == 2)
        #expect(HRSample.filtered(s, background: false, workouts: true).map(\.bpm) == [120])
        #expect(HRSample.filtered(s, background: true, workouts: false).map(\.bpm) == [60])
        #expect(HRSample.filtered(s, background: false, workouts: false).isEmpty)
    }

    @Test func lineBreaksOnLongGaps() {
        let s = [0.0, 60, 7200, 7260].map { HRSample(date: t0.addingTimeInterval($0), bpm: 70) }
        #expect(HRSample.segments(s) == [0, 0, 1, 1])
    }
}

@MainActor
struct MotionStripTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func mergesRunsAndSkipsUnknown() {
        let contexts: [MotionContext] = [.sedentary, .sedentary, .active, .unknown, .active]
        let s = contexts.enumerated().map {
            HRSample(date: t0.addingTimeInterval(Double($0.offset) * 60), bpm: 70, motion: $0.element)
        }
        let strips = HeartChart.motionStrips(s)
        #expect(strips.map(\.motion) == [.sedentary, .active, .active])
        #expect(strips[0].start == t0 && strips[0].end == t0.addingTimeInterval(120))
        #expect(strips.last?.end == t0.addingTimeInterval(300))   // sidste: + 1 min
    }
}

/// Korte etiketter, så periodeknappen ikke bryder over to linjer.
struct PeriodLabelTests {
    let now = Date(timeIntervalSince1970: 1_794_250_000)

    @Test func rollingSevenDays() {
        let i = DateInterval(start: now.addingTimeInterval(-7 * 86_400), end: now)
        #expect(Period.label(i, now: now) == "Seneste 7 dage")
    }

    @Test func rolling24Hours() {
        let i = DateInterval(start: now.addingTimeInterval(-86_400), end: now)
        #expect(Period.label(i, now: now) == "Seneste 24 timer")
    }

    @Test func rollingMonthAndYear() {
        let cal = Calendar.current
        #expect(Period.label(DateInterval(start: cal.date(byAdding: .month, value: -1, to: now)!, end: now), now: now)
                == "Seneste måned")
        #expect(Period.label(DateInterval(start: cal.date(byAdding: .year, value: -1, to: now)!, end: now), now: now)
                == "Seneste år")
    }
}

/// Perioder, der følger "nu", flyttes med, når appen kommer frem igen.
struct PeriodRefreshTests {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        return c
    }()
    func date(_ d: Int, _ h: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    @Test func todayMovesToNewDay() {
        let then = date(9, 18), now = date(10, 7)
        let r = Period.refreshed(Period.day(containing: then, calendar: cal), from: then, to: now, calendar: cal)
        #expect(r == Period.day(containing: now, calendar: cal))
    }

    @Test func thisWeekMovesToNewWeek() {
        let then = date(8, 20), now = date(10, 7)   // søndag → mandag i ny uge
        let r = Period.refreshed(Period.thisWeek(now: then, calendar: cal), from: then, to: now, calendar: cal)
        #expect(r == Period.thisWeek(now: now, calendar: cal))
    }

    @Test func rollingWindowFollowsNow() {
        let then = date(9, 18), now = date(10, 7)
        let r = Period.refreshed(DateInterval(start: then.addingTimeInterval(-7 * 86_400), end: then),
                                 from: then, to: now, calendar: cal)
        #expect(r.end == now)
        #expect(r.duration == 7 * 86_400)
    }

    @Test func olderPeriodStays() {
        let then = date(9, 18), now = date(10, 7)
        let old = Period.thisWeek(now: date(1, 12), calendar: cal)
        #expect(Period.refreshed(old, from: then, to: now, calendar: cal) == old)
    }
}
