import Foundation

/// Cumulative active minutes: time in the moderate zone × moderate weight + time in the vigorous zone × vigorous
/// weight.
/// Between two measurements the heart rate is assumed to change linearly. If it crosses a zone limit, the time is split
/// exactly at the limit (e.g. 85 → 105 bpm over 2 min with limit 90: only the time above 90 counts). A gap longer than
/// `maxGap` (nothing was measured) doesn't count – except within the same workout when `fillWorkoutGaps` is on.
/// `maxGap` = nil: all gaps count, however long.
struct ActiveMinutes: Equatable {
    struct Point: Identifiable, Equatable {
        let id: Int
        let date: Date
        let total: Double
        /// The part of the total that comes from workouts (the rest is background measurements).
        var workout: Double = 0
        var background: Double { total - workout }
    }

    /// Default: the longest time between two measurements before the time no longer counts.
    static let maxGap: TimeInterval = 300
    static let maxPoints = 1000

    var points: [Point] = []
    /// Minutes (unweighted) in each zone, lowest zone first.
    var zoneMinutes: [Double] = []
    /// Two zones: minutes in the moderate and vigorous zone.
    var moderateMinutes: Double { zoneMinutes.count > 1 ? zoneMinutes[1] : 0 }
    var vigorousMinutes: Double { zoneMinutes.count > 2 ? zoneMinutes[2...].reduce(0, +) : 0 }
    var total: Double = 0
    /// Minutes (weighted) from workouts; the rest of the total is from background measurements.
    var workoutTotal: Double = 0
    var backgroundTotal: Double { total - workoutTotal }

    /// What decides whether you are "active" (used with "Only when active"). One simple setting for when background
    /// heart rate counts. It drives the underlying settings (only when active, active according to, fill pauses).
    enum ActivityMode: String, CaseIterable, Identifiable {
        case always, watch, watchWithPauses, watchOrRing, withPauses
        var id: String { rawValue }
        var title: String {
            switch self {
            case .always: String(localized: "All heart rate")
            case .watch: String(localized: "Only when active")
            case .watchWithPauses: String(localized: "Active and short pauses")
            case .watchOrRing: String(localized: "Active or Exercise ring")
            case .withPauses: String(localized: "Active, Exercise ring and short pauses")
            }
        }
        /// Short text for the row in Settings.
        var shortTitle: String {
            switch self {
            case .always: String(localized: "All heart rate")
            case .watch: String(localized: "Active")
            case .watchWithPauses: String(localized: "Active + pauses")
            case .watchOrRing: String(localized: "Active/ring")
            case .withPauses: String(localized: "Active/ring + pauses")
            }
        }
        var explanation: String {
            switch self {
            case .always: String(localized: "All heart rate in the zones counts – including high heart rate at rest, e.g. from stress or coffee.")
            case .watch: String(localized: "Only when Apple Watch marks you as active – mostly based on steps. Gardening and cleaning often don’t count.")
            case .watchWithPauses: String(localized: "Like “Only when active”, but two active stretches are joined when the pause between them is short – without the Exercise ring.")
            case .watchOrRing: String(localized: "Like “Only when active”, plus the minutes that count in the green Exercise ring (heart rate and movement).")
            case .withPauses: String(localized: "Like “Active or Exercise ring”, but two active stretches are joined when the pause between them is short – good for e.g. gardening, cleaning and play.")
            }
        }
    }

    enum ActivitySource: String, CaseIterable, Identifiable {
        case watchMotion, exerciseRing, either
        var id: String { rawValue }
        var title: String {
            switch self {
            case .watchMotion: String(localized: "Apple Watch marking")
            case .exerciseRing: String(localized: "Exercise ring")
            case .either: String(localized: "Marking or ring")
            }
        }
        var explanation: String {
            switch self {
            case .watchMotion: String(localized: "Active when Apple Watch has marked the measurement “active” (mostly based on steps and movement).")
            case .exerciseRing: String(localized: "Active in the minutes that count in the Exercise ring (the green ring – heart rate and movement).")
            case .either: String(localized: "Active when Apple Watch has marked the measurement “active”, or the minute counts in the Exercise ring.")
            }
        }
    }

    /// Does a measurement count when "Only when active" is on? During a workout it always counts (you are exercising –
    /// Apple Watch often marks workout measurements as "resting", e.g. during strength training). Otherwise `source`
    /// decides: Apple Watch's marking, the Exercise ring (Exercise minutes in the same minute) or either.
    static func countsAsActive(_ s: HRSample, source: ActivitySource = .watchMotion) -> Bool {
        if s.inWorkout || s.bridgedActive { return true }
        let marked = s.motion == .active
        switch source {
        case .watchMotion: return marked
        case .exerciseRing: return s.inExercise
        case .either: return marked || s.inExercise
        }
    }

    /// The settings the calculation depends on.
    struct Config: Equatable {
        /// The zones with limits and a factor per zone.
        var zones: HeartZones
        var requireActive: Bool
        var fillWorkoutGaps: Bool = true
        /// Longest gap that counts (nil = no limit).
        var maxGap: TimeInterval? = ActiveMinutes.maxGap
        /// How the heart rate between two measurements is calculated.
        var interpolation: Interpolation = .linear
        /// What decides "active" (with requireActive).
        var activitySource: ActivitySource = .watchMotion
        /// Gaps of at most this long between two active measurements count as active (0 = off).
        var activeBridge: TimeInterval = 0

        init(zones: HeartZones, requireActive: Bool, fillWorkoutGaps: Bool = true,
             maxGap: TimeInterval? = ActiveMinutes.maxGap, interpolation: Interpolation = .linear,
             activitySource: ActivitySource = .watchMotion, activeBridge: TimeInterval = 0) {
            self.zones = zones
            self.requireActive = requireActive
            self.fillWorkoutGaps = fillWorkoutGaps
            self.maxGap = maxGap
            self.interpolation = interpolation
            self.activitySource = activitySource
            self.activeBridge = activeBridge
        }

        /// Two zones with factors for moderate and vigorous (used in the tests).
        init(zones: HeartZones, moderateWeight: Double, vigorousWeight: Double, requireActive: Bool,
             fillWorkoutGaps: Bool = true, maxGap: TimeInterval? = ActiveMinutes.maxGap,
             interpolation: Interpolation = .linear, activitySource: ActivitySource = .watchMotion,
             activeBridge: TimeInterval = 0) {
            self.init(zones: zones.withWeights([0, moderateWeight, vigorousWeight]), requireActive: requireActive,
                      fillWorkoutGaps: fillWorkoutGaps, maxGap: maxGap, interpolation: interpolation,
                      activitySource: activitySource, activeBridge: activeBridge)
        }
    }

    /// "Fill short gaps": measurements between two active measurements count as active when there is at most
    /// `maxBridge` between the two active measurements (e.g. gardening, where Apple only marks parts as active).
    static func bridgingActive(_ samples: [HRSample], config: Config) -> [HRSample] {
        guard config.requireActive, config.activeBridge > 0 else { return samples }
        var out = samples
        var lastActive: Int?
        for j in samples.indices where countsAsActive(samples[j], source: config.activitySource) {
            if let i = lastActive, j - i > 1,
               samples[j].date.timeIntervalSince(samples[i].date) <= config.activeBridge {
                for k in (i + 1)..<j { out[k].bridgedActive = true }
            }
            lastActive = j
        }
        return out
    }

    /// What the heart rate between two measurements is assumed to be.
    enum Interpolation: String, CaseIterable, Identifiable {
        case linear, previous, next, nearest, lowest
        var id: String { rawValue }
        var title: String {
            switch self {
            case .linear: String(localized: "Straight line")
            case .previous: String(localized: "Previous measurement (step)")
            case .next: String(localized: "Next measurement (step)")
            case .nearest: String(localized: "Nearest measurement")
            case .lowest: String(localized: "Lower of the two")
            }
        }
        var explanation: String {
            switch self {
            case .linear: String(localized: "Heart rate changes evenly between measurements; the time is split where it crosses a limit.")
            case .previous: String(localized: "Each measurement applies until the next one arrives.")
            case .next: String(localized: "Each measurement applies back to the previous one.")
            case .nearest: String(localized: "The first half of the time follows the previous measurement, the second half the next.")
            case .lowest: String(localized: "Cautious: the time only counts in the zone both measurements reach at least.")
            }
        }
        /// All methods with explanations (for ⓘ in Settings).
        static var allExplained: String {
            String(localized: "Heart rate is only measured now and then. Here you choose what the heart rate is assumed to be between two measurements:") + "\n\n"
                + allCases.map { "• \($0.title): \($0.explanation)" }.joined(separator: "\n")
        }
    }

    /// Cumulative minutes from Exercise minutes (the green ring), one value per sample.
    static func cumulativeExercise(_ samples: [(end: Date, minutes: Double)], start: Date) -> [Point] {
        var total = 0.0
        var points = [Point(id: 0, date: start, total: 0)]
        for s in samples.sorted(by: { $0.end < $1.end }) {
            total += s.minutes
            points.append(Point(id: points.count, date: s.end, total: total))
        }
        return points
    }

    /// Extends a cumulative curve horizontally to `end` (e.g. now) so it continues through days without new minutes –
    /// the sum just stays flat.
    static func extended(_ points: [Point], to end: Date) -> [Point] {
        guard let last = points.last, end > last.date else { return points }
        let id = (points.map(\.id).max() ?? 0) + 1
        return points + [Point(id: id, date: end, total: last.total, workout: last.workout)]
    }

    /// The curve from the start of the period (0) to `end`: starts at 0 at `start` if the first measurement comes later
    /// (e.g. workouts only), and continues horizontally to `end`.
    static func spanning(_ points: [Point], from start: Date, to end: Date) -> [Point] {
        var p = points
        if let first = p.first, first.date > start {
            let id = (p.map(\.id).min() ?? 0) - 1
            p.insert(Point(id: id, date: start, total: 0), at: 0)
        } else if p.isEmpty {
            p = [Point(id: 0, date: start, total: 0)]
        }
        return extended(p, to: end)
    }

    /// Cumulative points cut to a time range and counted from 0 at its start.
    static func rebased(_ points: [Point], to interval: DateInterval) -> [Point] {
        let base = points.last(where: { $0.date <= interval.start })?.total ?? 0
        let inside = points.filter { $0.date > interval.start && $0.date <= interval.end }
        return [Point(id: 0, date: interval.start, total: 0)]
            + inside.enumerated().map { Point(id: $0.offset + 1, date: $0.element.date, total: $0.element.total - base) }
    }

    /// How gaps in the measurements are handled during a workout.
    enum WorkoutGaps: String, CaseIterable, Identifiable {
        case sameLimit, betweenMeasurements, wholeWorkout
        var id: String { rawValue }
        var title: String {
            switch self {
            case .sameLimit: String(localized: "Same limit")
            case .betweenMeasurements: String(localized: "First–last")
            case .wholeWorkout: String(localized: "Whole workout")
            }
        }
        /// Continuation of "During workouts …" in the explanation.
        var summary: String {
            switch self {
            case .sameLimit: String(localized: "the same limit applies.")
            case .betweenMeasurements: String(localized: "all time from the first to the last measurement counts, regardless of gaps.")
            case .wholeWorkout: String(localized: "the whole workout counts from start to finish – including before the first and after the last measurement.")
            }
        }
        static var allExplained: String {
            String(localized: "During workouts, heart rate may be measured with gaps (e.g. during strength training or with a chest strap).") + "\n\n"
                + allCases.map { "• \($0.title): " + String(localized: "During workouts \($0.summary)") }.joined(separator: "\n")
        }
    }

    /// Do both measurements belong to the same workout?
    static func sameWorkout(_ a: HRSample, _ b: HRSample) -> Bool {
        a.workoutStart != nil && a.workoutStart == b.workoutStart
    }

    /// What happened to the time between two measurements.
    enum Kind: Equatable {
        case zone(Int)            // time in a zone (counts with the zone's factor; × 0 doesn't count)
        case notActive            // Apple Watch judged "resting" (only with "Only when active")
        case gap                  // more than maxGap without a measurement (outside workouts)

        /// Two zones: light (below moderate), moderate and vigorous.
        static let belowZone = Kind.zone(0)
        static let moderate = Kind.zone(1)
        static let vigorous = Kind.zone(2)
    }

    /// A piece of the interval a→b with one kind.
    struct Piece: Equatable {
        let start: Date
        let end: Date
        let kind: Kind
        var minutes: Double { end.timeIntervalSince(start) / 60 }
    }

    /// Splits the interval a→b at the zone limits (linear heart rate in between). Used by both the number and the
    /// intervals, so they always agree.
    static func pieces(_ a: HRSample, _ b: HRSample, config: Config) -> [Piece] {
        let dt = b.date.timeIntervalSince(a.date)
        guard dt > 0 else { return [] }
        guard (config.maxGap.map { dt <= $0 } ?? true) || (config.fillWorkoutGaps && sameWorkout(a, b)) else { return [Piece(start: a.date, end: b.date, kind: .gap)] }
        // Pieces of the interval (fraction from–to) with the heart rate that applies there.
        let segments: [(u: Double, v: Double, bpm: Double)]
        switch config.interpolation {
        case .previous: segments = [(0, 1, a.bpm)]
        case .next: segments = [(0, 1, b.bpm)]
        case .nearest: segments = [(0, 0.5, a.bpm), (0.5, 1, b.bpm)]
        case .lowest: segments = [(0, 1, min(a.bpm, b.bpm))]
        case .linear:
            var cuts: [Double] = [0, 1]
            for threshold in config.zones.thresholds
            where (a.bpm - threshold) * (b.bpm - threshold) < 0 {
                cuts.append((threshold - a.bpm) / (b.bpm - a.bpm))
            }
            cuts.sort()
            segments = zip(cuts, cuts.dropFirst()).filter { $0.1 > $0.0 }
                .map { (u, v) in (u, v, a.bpm + (b.bpm - a.bpm) * (u + v) / 2) }
        }
        let active = !config.requireActive || countsAsActive(a, source: config.activitySource)
        var result: [Piece] = []
        for (u, v, bpm) in segments {
            let zone = config.zones.zone(for: bpm)
            // Zones with × 0 never count, so "resting" only matters for zones that count.
            let kind: Kind = active || config.zones.weights[zone] == 0 ? .zone(zone) : .notActive
            result.append(Piece(start: a.date.addingTimeInterval(u * dt),
                                end: a.date.addingTimeInterval(v * dt), kind: kind))
        }
        return result
    }

    static func credit(_ piece: Piece, config: Config) -> Double {
        guard case .zone(let i) = piece.kind else { return 0 }
        return piece.minutes * config.zones.weights[i]
    }

    init(_ samples: [HRSample], zones: HeartZones,
         moderateWeight: Double, vigorousWeight: Double,
         requireActive: Bool = false, fillWorkoutGaps: Bool = true,
         maxGap: TimeInterval? = maxGap, interpolation: Interpolation = .linear) {
        self.init(samples, config: Config(zones: zones, moderateWeight: moderateWeight,
                                          vigorousWeight: vigorousWeight, requireActive: requireActive,
                                          fillWorkoutGaps: fillWorkoutGaps, maxGap: maxGap,
                                          interpolation: interpolation))
    }

    init(_ samples: [HRSample], config: Config) {
        let samples = Self.bridgingActive(samples, config: config)
        zoneMinutes = Array(repeating: 0, count: config.zones.count)
        guard let first = samples.first else { return }
        var all = [Point(id: 0, date: first.date, total: 0)]
        for (a, b) in zip(samples, samples.dropFirst()) {
            for p in Self.pieces(a, b, config: config) {
                if case .zone(let i) = p.kind { zoneMinutes[i] += p.minutes }
                let c = Self.credit(p, config: config)
                total += c
                if a.inWorkout { workoutTotal += c }
            }
            all.append(Point(id: all.count, date: b.date, total: total, workout: workoutTotal))
        }
        // Thin out to a manageable number of points, but always keep the last one.
        if all.count > Self.maxPoints {
            let step = Int((Double(all.count) / Double(Self.maxPoints)).rounded(.up))
            var thinned = stride(from: 0, to: all.count, by: step).map { all[$0] }
            if thinned.last != all.last, let last = all.last { thinned.append(last) }
            all = thinned
        }
        points = all
    }
}

extension ActiveMinutes {
    /// A stretch of time in the calculation (adjacent intervals of the same kind are merged).
    struct Interval: Identifiable, Equatable {
        let id: Int
        let start: Date
        var end: Date
        let kind: Kind
        var minutes: Double
        var credit: Double
    }

    /// The intervals between the measurements (used by the tests to check the calculation).
    static func intervals<C: RandomAccessCollection>(_ samples: C, config: Config) -> [Interval]
    where C.Element == HRSample {
        var result: [Interval] = []
        let samples = bridgingActive(Array(samples), config: config)
        for (a, b) in zip(samples, samples.dropFirst()) {
            for p in pieces(a, b, config: config) {
                let c = credit(p, config: config)
                if var last = result.last, last.kind == p.kind, last.end == p.start {
                    last.end = p.end
                    last.minutes += p.minutes
                    last.credit += c
                    result[result.count - 1] = last
                } else {
                    result.append(Interval(id: result.count, start: p.start, end: p.end,
                                           kind: p.kind, minutes: p.minutes, credit: c))
                }
            }
        }
        return result
    }

    /// Heart Minutes earned in the time range [from, to] (pieces crossing the edge count with the part inside). Only
    /// looks at the measurements around the range, so it is fast.
    static func credit(in samples: [HRSample], from: Date, to: Date, config: Config) -> Double {
        guard to > from, !samples.isEmpty else { return 0 }
        // A little margin (e.g. for "short pauses", which look at neighbouring measurements).
        let margin = max(config.activeBridge, config.maxGap ?? 0, 600)
        let lo = max(samples.firstIndex(atOrAfter: from.addingTimeInterval(-margin)) - 1, 0)
        let hi = min(samples.firstIndex(atOrAfter: to.addingTimeInterval(margin)) + 1, samples.count)
        guard lo < hi else { return 0 }
        return intervals(samples[lo..<hi], config: config).reduce(0) { sum, iv in
            let a = max(iv.start, from), b = min(iv.end, to)
            let len = iv.end.timeIntervalSince(iv.start)
            guard b > a, len > 0 else { return sum }
            return sum + iv.credit * b.timeIntervalSince(a) / len
        }
    }

    /// Stretches each workout's measurements to the whole workout: the first measurement applies from the workout's
    /// start, the last one until its end.
    static func extendingWorkouts(_ samples: [HRSample], _ workouts: [DateInterval]) -> [HRSample] {
        guard !workouts.isEmpty else { return samples }
        var first: [Date: HRSample] = [:], last: [Date: HRSample] = [:]
        for s in samples {
            guard let w = s.workoutStart else { continue }
            if first[w] == nil { first[w] = s }
            last[w] = s
        }
        var extra: [HRSample] = []
        for w in workouts {
            guard let f = first[w.start], let l = last[w.start] else { continue }
            if f.date > w.start { extra.append(f.copy(at: w.start)) }
            if l.date < w.end { extra.append(l.copy(at: w.end)) }
        }
        guard !extra.isEmpty else { return samples }
        return (samples + extra).sorted { $0.date < $1.date }
    }

    /// Points for one workout (to compare workout by workout).
    struct WorkoutScore: Identifiable, Equatable {
        var id: Date { interval.start }
        let interval: DateInterval
        let result: ActiveMinutes
        let sampleCount: Int
    }

    /// Calculates each workout separately from the measurements that belong to it.
    static func perWorkout(_ samples: [HRSample], workouts: [DateInterval], config: Config) -> [WorkoutScore] {
        var byWorkout: [Date: [HRSample]] = [:]
        for s in samples { if let w = s.workoutStart { byWorkout[w, default: []].append(s) } }
        return workouts.sorted { $0.start < $1.start }.map { w in
            let s = byWorkout[w.start] ?? []
            return WorkoutScore(interval: w, result: ActiveMinutes(s, config: config), sampleCount: s.count)
        }
    }

    /// The weekly goal scaled to the length of the period (e.g. 150 min/week → about 21 min for one day).
    static func scaledGoal(weekly: Double, duration: TimeInterval) -> Double {
        weekly * duration / (7 * 86_400)
    }
}
