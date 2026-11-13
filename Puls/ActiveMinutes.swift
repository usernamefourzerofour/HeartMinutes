import Foundation

/// Kumulative aktive minutter: tid i moderat zone × moderatvægt + tid i hård zone × hårdvægt.
///
/// Mellem to målinger antages pulsen at ændre sig lineært. Krydser den en zonegrænse, deles
/// tiden præcis ved grænsen (fx 85 → 105 bpm over 2 min med grænse 90: kun tiden over 90 tæller).
/// Er hullet større end `maxGap` (der er ikke målt), tælles det ikke med – undtagen inden for
/// samme workout, når `fillWorkoutGaps` er slået til.
/// `maxGap` = nil: alle huller tæller, lige meget hvor lange.
struct ActiveMinutes: Equatable {
    struct Point: Identifiable, Equatable {
        let id: Int
        let date: Date
        let total: Double
        /// Den del af total, der kommer fra workouts (resten er baggrundsmålinger).
        var workout: Double = 0
        var background: Double { total - workout }
    }

    /// Standard: højst så lang tid mellem to målinger, før tiden ikke tælles med.
    static let maxGap: TimeInterval = 300
    static let maxPoints = 1000

    var points: [Point] = []
    /// Minutter (uvægtede) i hver zone, nederste zone først.
    var zoneMinutes: [Double] = []
    /// To zoner: minutter i moderat og hård zone.
    var moderateMinutes: Double { zoneMinutes.count > 1 ? zoneMinutes[1] : 0 }
    var vigorousMinutes: Double { zoneMinutes.count > 2 ? zoneMinutes[2...].reduce(0, +) : 0 }
    var total: Double = 0
    /// Minutter (vægtede) fra workouts; resten af total er fra baggrundsmålinger.
    var workoutTotal: Double = 0
    var backgroundTotal: Double { total - workoutTotal }

    /// Hvad der afgør, om man er "aktiv" (bruges med "Kun når aktiv").
    /// Én samlet, letforståelig indstilling for, hvornår baggrundspuls tæller.
    /// Styrer de underliggende indstillinger (kun når aktiv, aktiv ifølge, udfyld pauser).
    enum ActivityMode: String, CaseIterable, Identifiable {
        case always, watch, watchWithPauses, watchOrRing, withPauses
        var id: String { rawValue }
        var title: String {
            switch self {
            case .always: "Al puls"
            case .watch: "Kun når aktiv"
            case .watchWithPauses: "Aktiv og korte pauser"
            case .watchOrRing: "Aktiv eller træningsring"
            case .withPauses: "Aktiv, træningsring og korte pauser"
            }
        }
        /// Kort tekst til rækken i Indstillinger.
        var shortTitle: String {
            switch self {
            case .always: "Al puls"
            case .watch: "Aktiv"
            case .watchWithPauses: "Aktiv + pauser"
            case .watchOrRing: "Aktiv/ring"
            case .withPauses: "Aktiv/ring + pauser"
            }
        }
        var explanation: String {
            switch self {
            case .always: "Al puls i zonerne tæller – også høj puls i ro, fx stress eller kaffe."
            case .watch: "Kun når Apple Watch markerer dig aktiv – det bygger mest på skridt. Havearbejde og rengøring tæller ofte ikke."
            case .watchWithPauses: "Som »Kun når aktiv«, men to aktive stykker kædes sammen, når pausen imellem er kort – uden træningsringen."
            case .watchOrRing: "Som »Kun når aktiv«, plus de minutter, der tæller i den grønne træningsring (puls og bevægelse)."
            case .withPauses: "Som »Aktiv eller træningsring«, men to aktive stykker kædes sammen, når pausen imellem er kort – godt til fx havearbejde, rengøring og leg."
            }
        }
    }

    enum ActivitySource: String, CaseIterable, Identifiable {
        case watchMotion, exerciseRing, either
        var id: String { rawValue }
        var title: String {
            switch self {
            case .watchMotion: "Apple Watch-markering"
            case .exerciseRing: "Træningsring"
            case .either: "Markering eller ring"
            }
        }
        var explanation: String {
            switch self {
            case .watchMotion: "Aktiv, når Apple Watch har markeret målingen »aktiv« (bygger mest på skridt og bevægelse)."
            case .exerciseRing: "Aktiv i de minutter, der tæller i træningsringen (den grønne ring – puls og bevægelse)."
            case .either: "Aktiv, når enten Apple Watch har markeret målingen »aktiv«, eller minuttet tæller i træningsringen."
            }
        }
    }

    /// Tæller en måling med, når "Kun når aktiv" er slået til?
    /// Under en workout tæller målingen altid (man træner jo – Apple Watch markerer tit workout-målinger
    /// som "i ro", fx ved styrketræning). Ellers afgør `source`: Apple Watchs markering, træningsringen
    /// (træningsringsminutter i samme minut) eller én af dem.
    static func countsAsActive(_ s: HRSample, source: ActivitySource = .watchMotion) -> Bool {
        if s.inWorkout || s.bridgedActive { return true }
        let marked = s.motion == .active
        switch source {
        case .watchMotion: return marked
        case .exerciseRing: return s.inExercise
        case .either: return marked || s.inExercise
        }
    }

    /// Indstillingerne beregningen afhænger af.
    struct Config: Equatable {
        /// Zonerne med grænser og faktor pr. zone.
        var zones: HeartZones
        var requireActive: Bool
        var fillWorkoutGaps: Bool = true
        /// Længste hul der tælles med (nil = ingen grænse).
        var maxGap: TimeInterval? = ActiveMinutes.maxGap
        /// Hvordan pulsen mellem to målinger regnes.
        var interpolation: Interpolation = .linear
        /// Hvad der afgør "aktiv" (med requireActive).
        var activitySource: ActivitySource = .watchMotion
        /// Huller på højst så lang tid mellem to aktive målinger tæller som aktive (0 = fra).
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

        /// To zoner med faktor for moderat og hård (bruges i testene).
        init(zones: HeartZones, moderateWeight: Double, vigorousWeight: Double, requireActive: Bool,
             fillWorkoutGaps: Bool = true, maxGap: TimeInterval? = ActiveMinutes.maxGap,
             interpolation: Interpolation = .linear, activitySource: ActivitySource = .watchMotion,
             activeBridge: TimeInterval = 0) {
            self.init(zones: zones.withWeights([0, moderateWeight, vigorousWeight]), requireActive: requireActive,
                      fillWorkoutGaps: fillWorkoutGaps, maxGap: maxGap, interpolation: interpolation,
                      activitySource: activitySource, activeBridge: activeBridge)
        }
    }

    /// "Udfyld korte huller": målinger mellem to aktive målinger tæller som aktive, når der højst er
    /// `maxBridge` mellem de to aktive målinger (fx havearbejde, hvor Apple kun markerer stykker som aktive).
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

    /// Hvordan pulsen mellem to målinger antages at være.
    enum Interpolation: String, CaseIterable, Identifiable {
        case linear, previous, next, nearest, lowest
        var id: String { rawValue }
        var title: String {
            switch self {
            case .linear: "Lige linje"
            case .previous: "Forrige måling (trin)"
            case .next: "Næste måling (trin)"
            case .nearest: "Nærmeste måling"
            case .lowest: "Laveste af de to"
            }
        }
        var explanation: String {
            switch self {
            case .linear: "Pulsen ændrer sig jævnt mellem målingerne; tiden deles, hvor den krydser en grænse."
            case .previous: "Hver måling gælder, indtil den næste kommer."
            case .next: "Hver måling gælder tilbage til den forrige."
            case .nearest: "Første halvdel af tiden følger den forrige måling, anden halvdel den næste."
            case .lowest: "Forsigtig: tiden tæller kun i den zone, begge målinger mindst når."
            }
        }
        /// Alle metoder med forklaring (til ⓘ i Indstillinger).
        static var allExplained: String {
            "Pulsen måles kun en gang imellem. Her vælger du, hvad pulsen antages at være mellem to målinger:\n\n"
                + allCases.map { "• \($0.title): \($0.explanation)" }.joined(separator: "\n")
        }
    }

    /// Kumulative minutter fra træningsringsminutter (den grønne ring), en værdi pr. sample.
    static func cumulativeExercise(_ samples: [(end: Date, minutes: Double)], start: Date) -> [Point] {
        var total = 0.0
        var points = [Point(id: 0, date: start, total: 0)]
        for s in samples.sorted(by: { $0.end < $1.end }) {
            total += s.minutes
            points.append(Point(id: points.count, date: s.end, total: total))
        }
        return points
    }

    /// Forlænger en kumulativ kurve vandret til `end` (fx nu), så den fortsætter gennem dage uden
    /// nye minutter – summen står bare stille.
    static func extended(_ points: [Point], to end: Date) -> [Point] {
        guard let last = points.last, end > last.date else { return points }
        let id = (points.map(\.id).max() ?? 0) + 1
        return points + [Point(id: id, date: end, total: last.total, workout: last.workout)]
    }

    /// Kurven fra periodens start (0) til `end`: starter i 0 ved `start`, hvis første måling kommer
    /// senere (fx kun workouts), og fortsætter vandret til `end`.
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

    /// Kumulative punkter skåret til et tidsrum og talt fra 0 ved dets start.
    static func rebased(_ points: [Point], to interval: DateInterval) -> [Point] {
        let base = points.last(where: { $0.date <= interval.start })?.total ?? 0
        let inside = points.filter { $0.date > interval.start && $0.date <= interval.end }
        return [Point(id: 0, date: interval.start, total: 0)]
            + inside.enumerated().map { Point(id: $0.offset + 1, date: $0.element.date, total: $0.element.total - base) }
    }

    /// Hvordan huller i målingerne behandles under en workout.
    enum WorkoutGaps: String, CaseIterable, Identifiable {
        case sameLimit, betweenMeasurements, wholeWorkout
        var id: String { rawValue }
        var title: String {
            switch self {
            case .sameLimit: "Samme grænse"
            case .betweenMeasurements: "Første–sidste"
            case .wholeWorkout: "Hele workout"
            }
        }
        /// Fortsættelse af "Under workouts …" i forklaringen.
        var summary: String {
            switch self {
            case .sameLimit: "gælder samme grænse."
            case .betweenMeasurements: "tæller al tid fra første til sidste måling, uanset huller."
            case .wholeWorkout: "tæller hele workouten fra start til slut – også før første og efter sidste måling."
            }
        }
        static var allExplained: String {
            "Under workouts kan pulsen være målt med pauser (fx ved styrketræning eller med en pulsrem).\n\n"
                + allCases.map { "• \($0.title): Under workouts \($0.summary)" }.joined(separator: "\n")
        }
    }

    /// Hører begge målinger til samme workout?
    static func sameWorkout(_ a: HRSample, _ b: HRSample) -> Bool {
        a.workoutStart != nil && a.workoutStart == b.workoutStart
    }

    /// Hvad der skete med tiden mellem to målinger.
    enum Kind: Equatable {
        case zone(Int)            // tiden i en zone (tæller med zonens faktor; × 0 tæller ikke)
        case notActive            // Apple Watch vurderede "i ro" (kun med "Kun når aktiv")
        case gap                  // mere end maxGap uden måling (uden for workouts)

        /// To zoner: let (under moderat), moderat og hård.
        static let belowZone = Kind.zone(0)
        static let moderate = Kind.zone(1)
        static let vigorous = Kind.zone(2)
    }

    /// Et stykke af intervallet a→b med én slags.
    struct Piece: Equatable {
        let start: Date
        let end: Date
        let kind: Kind
        var minutes: Double { end.timeIntervalSince(start) / 60 }
    }

    /// Deler intervallet a→b op ved zonegrænserne (lineær puls imellem). Bruges af både tallet
    /// og intervallerne, så de altid er enige.
    static func pieces(_ a: HRSample, _ b: HRSample, config: Config) -> [Piece] {
        let dt = b.date.timeIntervalSince(a.date)
        guard dt > 0 else { return [] }
        guard (config.maxGap.map { dt <= $0 } ?? true) || (config.fillWorkoutGaps && sameWorkout(a, b)) else { return [Piece(start: a.date, end: b.date, kind: .gap)] }
        // Stykker af intervallet (andel fra–til) med den puls, der gælder dér.
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
            // Zoner med × 0 tæller aldrig, så "i ro" er kun interessant for zoner, der tæller.
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
        // Tynd ud til en håndterbar mængde punkter, men behold altid det sidste.
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
    /// Et stykke tid i beregningen (sammenhængende intervaller af samme slags er slået sammen).
    struct Interval: Identifiable, Equatable {
        let id: Int
        let start: Date
        var end: Date
        let kind: Kind
        var minutes: Double
        var credit: Double
    }

    /// Intervallerne mellem målingerne (bruges af testene til at tjekke beregningen).
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

    /// Heart Minutes optjent i tidsrummet [from, to] (stykker, der krydser kanten, tæller med den
    /// del, der ligger indenfor). Regner kun på målingerne omkring tidsrummet, så det er hurtigt.
    static func credit(in samples: [HRSample], from: Date, to: Date, config: Config) -> Double {
        guard to > from, !samples.isEmpty else { return 0 }
        // Lidt margin (bl.a. til "korte pauser", der kigger på nabomålinger).
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

    /// Strækker hver workouts målinger ud til hele workouten: første måling gælder fra workoutens
    /// start, sidste måling til dens slut.
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

    /// Point for én workout (til sammenligning workout for workout).
    struct WorkoutScore: Identifiable, Equatable {
        var id: Date { interval.start }
        let interval: DateInterval
        let result: ActiveMinutes
        let sampleCount: Int
    }

    /// Regner hver workout for sig ud fra målingerne, der hører til den.
    static func perWorkout(_ samples: [HRSample], workouts: [DateInterval], config: Config) -> [WorkoutScore] {
        var byWorkout: [Date: [HRSample]] = [:]
        for s in samples { if let w = s.workoutStart { byWorkout[w, default: []].append(s) } }
        return workouts.sorted { $0.start < $1.start }.map { w in
            let s = byWorkout[w.start] ?? []
            return WorkoutScore(interval: w, result: ActiveMinutes(s, config: config), sampleCount: s.count)
        }
    }

    /// Ugemålet skaleret til periodens længde (fx 150 min/uge → ca. 21 min for én dag).
    static func scaledGoal(weekly: Double, duration: TimeInterval) -> Double {
        weekly * duration / (7 * 86_400)
    }
}
