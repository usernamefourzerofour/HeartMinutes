import Testing
import Foundation
@testable import HeartMinutes

/// Zones in the tests: moderate from 100, vigorous from 130 bpm. Heart rate is linear between measurements.
@MainActor
struct ActiveMinutesTests {
    let t0 = Date(timeIntervalSince1970: 0)
    let zones = HeartZones(moderate: 100, vigorous: 130)

    func samples(_ bpms: [Double], every seconds: Double = 60) -> [HRSample] {
        bpms.enumerated().map { HRSample(date: t0.addingTimeInterval(Double($0.offset) * seconds), bpm: $0.element) }
    }

    func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.0001 }

    @Test func splitsAtThresholds() {
        // 80→110: 1/3 min moderate · 110→110: 1 · 110→140: 2/3 moderate + 1/3 vigorous · 140→140: 1 vigorous
        let r = ActiveMinutes(samples([80, 110, 110, 140, 140]), zones: zones,
                              moderateWeight: 1, vigorousWeight: 2)
        #expect(close(r.moderateMinutes, 2))
        #expect(close(r.vigorousMinutes, 4.0 / 3))
        #expect(close(r.total, 2 + 8.0 / 3))
        #expect(r.points.first?.total == 0)
    }

    @Test func customWeights() {
        let r = ActiveMinutes(samples([110, 140, 140]), zones: zones,
                              moderateWeight: 0.5, vigorousWeight: 3)
        #expect(close(r.total, 0.5 * 2.0 / 3 + 3 * 4.0 / 3))
    }

    @Test func ignoresLongGaps() {
        let r = ActiveMinutes(samples([110, 110], every: 3600), zones: zones,
                              moderateWeight: 1, vigorousWeight: 2)
        #expect(r.total == 0)
    }

    @Test func emptyIsZero() {
        let r = ActiveMinutes([], zones: zones, moderateWeight: 1, vigorousWeight: 2)
        #expect(r.total == 0 && r.points.isEmpty)
    }

    @Test func belowZoneCountsNothing() {
        let r = ActiveMinutes(samples([80, 90, 95]), zones: zones, moderateWeight: 1, vigorousWeight: 2)
        #expect(r.total == 0)
    }
}

@MainActor
struct ActiveOnlyTests {
    let t0 = Date(timeIntervalSince1970: 0)
    let zones = HeartZones(moderate: 100, vigorous: 130)

    @Test func requireActiveSkipsSedentary() {
        let motions: [MotionContext] = [.sedentary, .active, .unknown, .active]
        let s = motions.enumerated().map {
            HRSample(date: t0.addingTimeInterval(Double($0.offset) * 60), bpm: 110, motion: $0.element)
        }
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2).total == 3)
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2,
                              requireActive: true).total == 1)
    }

    @Test func sedentaryCountsDuringWorkout() {
        var a = HRSample(date: t0, bpm: 110, motion: .sedentary); a.inWorkout = true
        var b = HRSample(date: t0.addingTimeInterval(60), bpm: 110, motion: .sedentary); b.inWorkout = true
        #expect(ActiveMinutes([a, b], zones: zones, moderateWeight: 1, vigorousWeight: 2,
                              requireActive: true).total == 1)
    }

    @Test func unknownCountsDuringWorkout() {
        var w = HRSample(date: t0, bpm: 140); w.inWorkout = true
        let s = [w, HRSample(date: t0.addingTimeInterval(60), bpm: 140)]
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2,
                              requireActive: true).total == 2)
    }
}

struct GoalTests {
    @Test func scalesWeeklyGoalToPeriod() {
        #expect(ActiveMinutes.scaledGoal(weekly: 150, duration: 7 * 86_400) == 150)
        #expect(abs(ActiveMinutes.scaledGoal(weekly: 150, duration: 86_400) - 150.0 / 7) < 0.0001)
        #expect(ActiveMinutes.scaledGoal(weekly: 150, duration: 14 * 86_400) == 300)
    }
}

@MainActor
struct PiecesTests {
    let t0 = Date(timeIntervalSince1970: 0)
    let config = ActiveMinutes.Config(zones: HeartZones(moderate: 100, vigorous: 130),
                                      moderateWeight: 1, vigorousWeight: 2, requireActive: false)

    func s(_ sec: Double, _ bpm: Double) -> HRSample { HRSample(date: t0.addingTimeInterval(sec), bpm: bpm) }

    @Test func pieceKinds() {
        #expect(ActiveMinutes.pieces(s(0, 110), s(60, 120), config: config).map(\.kind) == [.moderate])
        #expect(ActiveMinutes.pieces(s(0, 140), s(60, 80), config: config).map(\.kind)
                == [.vigorous, .moderate, .belowZone])
        #expect(ActiveMinutes.pieces(s(0, 110), s(400, 110), config: config).map(\.kind) == [.gap])
    }

    @Test func interpolationModes() {
        // 85 → 105 over 120 s, limit 100. Straight line: 30 s moderate.
        func moderateSeconds(_ m: ActiveMinutes.Interpolation) -> Double {
            var c = config; c.interpolation = m
            return ActiveMinutes.pieces(s(0, 85), s(120, 105), config: c)
                .filter { $0.kind == .moderate }.reduce(0) { $0 + $1.minutes } * 60
        }
        #expect(abs(moderateSeconds(.linear) - 30) < 0.001)
        #expect(moderateSeconds(.previous) == 0)
        #expect(moderateSeconds(.next) == 120)
        #expect(moderateSeconds(.nearest) == 60)
        #expect(moderateSeconds(.lowest) == 0)
    }

    @Test func perWorkoutSplitsScores() {
        var a = s(0, 110), b = s(60, 110), c = s(3600, 110), d = s(3720, 110)
        a.inWorkout = true; b.inWorkout = true; c.inWorkout = true; d.inWorkout = true
        a.workoutStart = t0; b.workoutStart = t0
        c.workoutStart = t0.addingTimeInterval(3600); d.workoutStart = t0.addingTimeInterval(3600)
        let ws = [DateInterval(start: t0, duration: 60), DateInterval(start: t0.addingTimeInterval(3600), duration: 120)]
        let scores = ActiveMinutes.perWorkout([a, b, c, d], workouts: ws, config: config)
        #expect(scores.map(\.result.total) == [1, 2])
        #expect(scores.map(\.sampleCount) == [2, 2])
    }

    @Test func crossingIsSplitAtThreshold() {
        // 85 → 105 over 120 s, limit 100: crosses after 90 s → 30 s moderate
        let p = ActiveMinutes.pieces(s(0, 85), s(120, 105), config: config)
        #expect(p.map(\.kind) == [.belowZone, .moderate])
        #expect(abs(p[1].minutes - 0.5) < 0.0001)
    }

    @Test func spikeCountsOnlyTimeAboveThreshold() {
        // 80 → 140 → 80, 3 min each way: per half 1.5 min moderate + 0.5 min vigorous
        let samples = [s(0, 80), s(180, 140), s(360, 80)]
        let r = ActiveMinutes(samples, zones: config.zones, moderateWeight: 1, vigorousWeight: 2,
                              maxGap: 600)
        #expect(abs(r.moderateMinutes - 3) < 0.0001)
        #expect(abs(r.vigorousMinutes - 1) < 0.0001)
    }

    @Test func intervalsMatchTotal() {
        let samples = [s(0, 110), s(60, 110), s(120, 110), s(180, 80), s(240, 140), s(300, 140)]
        let ivs = ActiveMinutes.intervals(samples, config: config)
        #expect(ivs.map(\.kind) == [.moderate, .belowZone, .moderate, .vigorous])
        let total = ActiveMinutes(samples, zones: config.zones, moderateWeight: 1, vigorousWeight: 2).total
        #expect(abs(ivs.reduce(0) { $0 + $1.credit } - total) < 0.0001)
    }
}

@MainActor
struct WorkoutGapTests {
    let t0 = Date(timeIntervalSince1970: 0)
    let zones = HeartZones(moderate: 100, vigorous: 130)

    func w(_ sec: Double, _ bpm: Double, start: Double = 0) -> HRSample {
        var s = HRSample(date: t0.addingTimeInterval(sec), bpm: bpm)
        s.inWorkout = true
        s.workoutStart = t0.addingTimeInterval(start)
        return s
    }

    @Test func gapInsideWorkoutCounts() {
        // 10 min between two measurements in the same workout, both 110 bpm → 10 min moderate
        let s = [w(0, 110), w(600, 110)]
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2).total == 10)
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2,
                              fillWorkoutGaps: false).total == 0)
    }

    @Test func gapBetweenWorkoutsDoesNotCount() {
        let s = [w(0, 110), w(3600, 110, start: 3600)]
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2).total == 0)
    }

    @Test func userDefinedAndUnlimitedGap() {
        let s = [HRSample(date: t0, bpm: 110), HRSample(date: t0.addingTimeInterval(600), bpm: 110)]
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2).total == 0)
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2,
                              maxGap: 900).total == 10)
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2,
                              maxGap: nil).total == 10)
    }

    @Test func extendsToWholeWorkout() {
        // Workout 0–600 s, but only measurements at 420 and 540 s (110 bpm) → the whole 10 min counts
        let workout = DateInterval(start: t0, duration: 600)
        let s = ActiveMinutes.extendingWorkouts([w(420, 110), w(540, 110)], [workout])
        #expect(s.map(\.date) == [0, 420, 540, 600].map { t0.addingTimeInterval($0) })
        #expect(ActiveMinutes(s, zones: zones, moderateWeight: 1, vigorousWeight: 2).total == 10)
    }

    @Test func markingSetsWorkoutStart() {
        let s = [HRSample(date: t0.addingTimeInterval(60), bpm: 70)]
        let marked = HRSample.markingWorkouts(s, [DateInterval(start: t0, duration: 120)])
        #expect(marked[0].workoutStart == t0)
    }
}

@MainActor
struct MaxHRModeTests {
    @Test func zonesFromMaxHR() {
        let z = HeartZones(maxHR: 187)
        #expect(abs(z.moderate - 93.5) < 0.0001)
        #expect(abs(z.vigorous - 130.9) < 0.0001)
    }
}

@MainActor
struct UnmarkedTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func countsUnmarkedBackgroundBySource() {
        var w = HRSample(date: t0, bpm: 120); w.inWorkout = true          // workout: doesn't count
        let s = [
            w,
            HRSample(date: t0.addingTimeInterval(60), bpm: 70, motion: .sedentary, source: "Watch"),
            HRSample(date: t0.addingTimeInterval(120), bpm: 70, source: "Ring"),
            HRSample(date: t0.addingTimeInterval(180), bpm: 70, source: "Ring"),
            HRSample(date: t0.addingTimeInterval(240), bpm: 70, source: "App"),
        ]
        let u = HRSample.unmarkedBackground(s)
        #expect(u.backgroundCount == 4)
        #expect(u.count == 3)
        #expect(u.sources == ["Ring", "App"])
        #expect(abs(u.fraction - 0.75) < 0.0001)
    }
}

@MainActor
struct SourceSplitTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func splitsWorkoutAndBackgroundMinutes() {
        // 2 min workout (110) and 1 min background (110), moderate from 100
        func s(_ sec: Double, workout: Bool) -> HRSample {
            var x = HRSample(date: t0.addingTimeInterval(sec), bpm: 110)
            x.inWorkout = workout
            if workout { x.workoutStart = t0 }
            return x
        }
        let samples = [s(0, workout: true), s(60, workout: true), s(120, workout: false), s(180, workout: false)]
        let r = ActiveMinutes(samples, zones: HeartZones(moderate: 100, vigorous: 130),
                              moderateWeight: 1, vigorousWeight: 2)
        #expect(abs(r.total - 3) < 0.0001)
        #expect(abs(r.workoutTotal - 2) < 0.0001)
        #expect(abs(r.backgroundTotal - 1) < 0.0001)
        #expect(abs((r.points.last?.workout ?? 0) - 2) < 0.0001)
    }
}

struct AppleExerciseTests {
    @Test func cumulatesExerciseMinutes() {
        let t0 = Date(timeIntervalSince1970: 0)
        let pts = ActiveMinutes.cumulativeExercise(
            [(end: t0.addingTimeInterval(180), minutes: 1), (end: t0.addingTimeInterval(120), minutes: 1),
             (end: t0.addingTimeInterval(600), minutes: 1)], start: t0)
        #expect(pts.map(\.total) == [0, 1, 2, 3])
        #expect(pts.map(\.date) == [0, 120, 180, 600].map { t0.addingTimeInterval($0) })
    }
}

struct ComplicationDataTests {
    @Test func resetsInNewWeek() {
        let now = Date.now
        let lastWeek = Period.thisWeek(now: now).start.addingTimeInterval(-3600)
        let old = ComplicationData(minutes: 120, goal: 150, updated: lastWeek)
        #expect(old.current(now: now).minutes == 0)
        let fresh = ComplicationData(minutes: 120, goal: 150, updated: now)
        #expect(fresh.current(now: now).minutes == 120)
        #expect(fresh.percent == 80)
    }
}

struct WidgetPointsTests {
    @Test func reducesToMaxKeepingEnds() {
        let t0 = Date(timeIntervalSince1970: 0)
        let pts = (0..<1000).map { ComplicationData.Point(t: t0.addingTimeInterval(Double($0)), v: Double($0)) }
        let r = ComplicationData.reduced(pts, max: 120)
        #expect(r.count == 120)
        #expect(r.first == pts.first && r.last == pts.last)
        #expect(ComplicationData.reduced(Array(pts.prefix(50))).count == 50)
    }
}

struct SummaryPeriodTests {
    @Test func goalsAndReset() {
        #expect(SummaryPeriod.today.goal(weekly: 140) == 20)
        #expect(SummaryPeriod.thisWeek.goal(weekly: 150) == 150)
        let now = Date.now
        let yesterday = Period.day(containing: now).start.addingTimeInterval(-60)
        let d = ComplicationData(minutes: 30, goal: 20, updated: yesterday)
        #expect(d.current(for: .today, now: now).minutes == 0)
        #expect(d.current(for: .last7Days, now: now).minutes == 30)
        #expect(SummaryPeriod.thisWeek.storageKey == "complicationData")
        #expect(SummaryPeriod.last14Days.goal(weekly: 150) == 300)
        #expect(SummaryPeriod.last3Days.rollingDays == 3)
        #expect(d.current(for: .last3Days, now: now).minutes == 30)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "Europe/Copenhagen")!
        let nov7 = cal.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 12))!
        #expect(SummaryPeriod.thisMonth.goalDays(now: nov7, calendar: cal) == 30)
        #expect(SummaryPeriod.thisMonth.interval(now: nov7, calendar: cal).start
                == cal.date(from: DateComponents(year: 2026, month: 11, day: 1)))
    }
}

struct RebaseTests {
    @Test func rebasesCumulativePoints() {
        let t0 = Date(timeIntervalSince1970: 0)
        let pts = [0, 60, 120, 180].enumerated().map {
            ActiveMinutes.Point(id: $0.offset, date: t0.addingTimeInterval(Double($0.element)), total: Double($0.offset) * 2)
        }
        let r = ActiveMinutes.rebased(pts, to: DateInterval(start: t0.addingTimeInterval(60), end: t0.addingTimeInterval(180)))
        #expect(r.map(\.total) == [0, 2, 4])
    }
}

@MainActor
struct ActivitySourceTests {
    let t0 = Date(timeIntervalSince1970: 0)

    @Test func exerciseRingCountsAsActive() {
        // Gardening: Apple Watch says "resting", but the minutes count in the Exercise ring.
        let raw = (0..<4).map { HRSample(date: t0.addingTimeInterval(Double($0) * 60), bpm: 140, motion: .sedentary) }
        let ring = [DateInterval(start: t0, duration: 60), DateInterval(start: t0.addingTimeInterval(60), duration: 60)]
        let s = HRSample.markingExercise(raw, ring)
        #expect(s.map(\.inExercise) == [true, true, false, false])
        let zones = HeartZones(moderate: 100, vigorous: 130)
        func total(_ src: ActiveMinutes.ActivitySource) -> Double {
            ActiveMinutes(s, config: .init(zones: zones, moderateWeight: 1, vigorousWeight: 2,
                                           requireActive: true, activitySource: src)).total
        }
        #expect(total(.watchMotion) == 0)
        #expect(total(.exerciseRing) == 4)   // 2 min in the vigorous zone × 2
        #expect(total(.either) == 4)
    }

    @Test func curveIsExtendedFlatToNow() {
        let p = [ActiveMinutes.Point(id: 0, date: t0, total: 0),
                 ActiveMinutes.Point(id: 1, date: t0.addingTimeInterval(3600), total: 30, workout: 10)]
        let e = ActiveMinutes.extended(p, to: t0.addingTimeInterval(86_400))
        #expect(e.count == 3)
        #expect(e.last?.total == 30 && e.last?.workout == 10)
        #expect(ActiveMinutes.extended(p, to: t0).count == 2)   // not backward
        #expect(Set(e.map(\.id)).count == 3)
        // Workouts only: first measurement in the middle of the period → the curve starts at 0 at the start of the
        // period.
        let s = ActiveMinutes.spanning(Array(p.dropFirst()), from: t0, to: t0.addingTimeInterval(86_400))
        #expect(s.first?.date == t0 && s.first?.total == 0)
        #expect(s.last?.total == 30)
        #expect(Set(s.map(\.id)).count == s.count)
        #expect(ActiveMinutes.spanning([], from: t0, to: t0.addingTimeInterval(60)).count == 2)
    }

    @Test func widgetCurveSpansFromPeriodStart() {
        let p = [ComplicationData.Point(t: t0.addingTimeInterval(86_400), v: 10)]
        let s = ComplicationData.spanning(p, from: t0, to: t0.addingTimeInterval(3 * 86_400))
        #expect(s.map(\.v) == [0, 10, 10])
        #expect(s.first?.t == t0)
    }

    @Test func bridgingFillsShortGaps() {
        // Active, two resting measurements, active again 3 min later, then resting at the end.
        let motions: [MotionContext] = [.active, .sedentary, .sedentary, .active, .sedentary, .sedentary]
        let s = motions.enumerated().map { HRSample(date: t0.addingTimeInterval(Double($0.offset) * 60), bpm: 110, motion: $0.element) }
        let zones = HeartZones(moderate: 100, vigorous: 130)
        func config(_ bridge: TimeInterval) -> ActiveMinutes.Config {
            .init(zones: zones, moderateWeight: 1, vigorousWeight: 2, requireActive: true,
                  activitySource: .watchMotion, activeBridge: bridge)
        }
        #expect(ActiveMinutes(s, config: config(0)).total == 2)        // only the minute after each active measurement
        #expect(ActiveMinutes(s, config: config(180)).total == 4)      // the 3 min gap is filled
        #expect(ActiveMinutes(s, config: config(120)).total == 2)      // limit too short
        #expect(ActiveMinutes.bridgingActive(s, config: config(180)).map(\.bridgedActive)
                == [false, true, true, false, false, false])
    }
}

struct CreditInRangeTests {
    @Test func creditOnlyInsideRange() {
        // 20 min constant moderate (× 1): the middle 10 min give 10 Heart Minutes.
        let t0 = Date(timeIntervalSince1970: 0)
        let s = (0...20).map { HRSample(date: t0.addingTimeInterval(Double($0) * 60), bpm: 110) }
        let config = ActiveMinutes.Config(zones: HeartZones(moderate: 100, vigorous: 130), requireActive: false)
        let c = ActiveMinutes.credit(in: s, from: t0.addingTimeInterval(5 * 60), to: t0.addingTimeInterval(15 * 60),
                                     config: config)
        #expect(abs(c - 10) < 0.001)
    }
}
