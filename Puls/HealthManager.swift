import HealthKit
import Observation

/// Apples egen vurdering af, om man bevægede sig, da pulsen blev målt
/// (HKMetadataKeyHeartRateMotionContext på Apple Watch-målinger).
enum MotionContext: Equatable {
    case unknown, sedentary, active

    init(_ metadata: [String: Any]?) {
        guard let raw = (metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber)?.intValue,
              let ctx = HKHeartRateMotionContext(rawValue: raw) else { self = .unknown; return }
        switch ctx {
        case .sedentary: self = .sedentary
        case .active: self = .active
        default: self = .unknown
        }
    }

    var name: String {
        switch self {
        case .unknown: "Ukendt"
        case .sedentary: "I ro"
        case .active: "Aktiv"
        }
    }
}

struct HRSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let bpm: Double
    /// Målt under en workout (ellers en baggrundsmåling).
    var inWorkout = false
    /// Om Apple vurderede, at man var aktiv eller i ro.
    var motion: MotionContext = .unknown
    /// Start på den workout, målingen hører til (så to målinger kan genkendes som samme workout).
    var workoutStart: Date? = nil
    /// Kilden i Sundhed (fx "min Apple Watch" eller en anden app/enhed).
    var source: String? = nil
    /// Målt i et minut, der tæller i træningsringen (den grønne ring).
    var inExercise = false
    /// Ligger i et kort hul mellem to aktive målinger og tæller derfor som aktiv ("Udfyld korte huller").
    var bridgedActive = false

    /// Samme måling på et andet tidspunkt (bruges til at strække en workouts målinger ud).
    func copy(at date: Date) -> HRSample {
        var s = HRSample(date: date, bpm: bpm, inWorkout: inWorkout, motion: motion)
        s.workoutStart = workoutStart
        s.source = source
        s.inExercise = inExercise
        s.bridgedActive = bridgedActive
        return s
    }

    /// Baggrundsmålinger uden markering for aktiv/i ro (den kommer kun fra Apple Watch).
    struct UnmarkedInfo: Equatable {
        let count: Int
        let backgroundCount: Int
        /// Kilderne, flest målinger først.
        let sources: [String]
        var fraction: Double { backgroundCount == 0 ? 0 : Double(count) / Double(backgroundCount) }
    }

    static func unmarkedBackground(_ samples: [HRSample]) -> UnmarkedInfo {
        var background = 0, unmarked = 0
        var perSource: [String: Int] = [:]
        for s in samples where !s.inWorkout {
            background += 1
            if s.motion == .unknown {
                unmarked += 1
                perSource[s.source ?? "Ukendt kilde", default: 0] += 1
            }
        }
        let sources = perSource.sorted { $0.value > $1.value }.map(\.key)
        return UnmarkedInfo(count: unmarked, backgroundCount: background, sources: sources)
    }

    /// Markerer de målinger, der falder inden for en af workout-perioderne.
    static func markingWorkouts(_ samples: [HRSample], _ workouts: [DateInterval]) -> [HRSample] {
        guard !workouts.isEmpty else { return samples }
        // Begge er sorteret efter tid: gå igennem én gang i stedet for at tjekke alle workouts pr. måling.
        let sorted = workouts.sorted { $0.start < $1.start }
        var w = 0
        return samples.map { s in
            var s = s
            while w < sorted.count && sorted[w].end < s.date { w += 1 }
            var i = w
            while i < sorted.count && sorted[i].start <= s.date {
                if sorted[i].contains(s.date) { s.inWorkout = true; s.workoutStart = sorted[i].start; break }
                i += 1
            }
            return s
        }
    }

    /// Markerer målinger, der ligger i et minut der tæller i træningsringen (den grønne ring).
    static func markingExercise(_ samples: [HRSample], _ minutes: [DateInterval]) -> [HRSample] {
        guard !minutes.isEmpty else { return samples }
        let sorted = minutes.sorted { $0.start < $1.start }
        var i = 0
        return samples.map { s in
            var s = s
            // Halvåbne minutter [start, slut), så en måling præcis på et minutskift kun hører til ét.
            while i < sorted.count && sorted[i].end <= s.date { i += 1 }
            if i < sorted.count && sorted[i].start <= s.date { s.inExercise = true }
            return s
        }
    }

    /// Pause, hvor linjen brydes (fx mellem to workouts, når baggrund er slået fra).
    static let lineBreakGap: TimeInterval = 3600

    /// Serienummer pr. sammenhængende stykke af samme type, så linjen skifter farve
    /// uden at forbinde baggrund og workout – og brydes ved huller over en time.
    static func segments(_ samples: [HRSample]) -> [Int] {
        var segment = 0
        return samples.indices.map { i in
            if i > 0 && (samples[i].inWorkout != samples[i - 1].inWorkout
                         || samples[i].date.timeIntervalSince(samples[i - 1].date) > lineBreakGap) {
                segment += 1
            }
            return segment
        }
    }

    /// Filtrerer efter indstillingerne for baggrunds- og workout-målinger.
    static func filtered(_ samples: [HRSample], background: Bool, workouts: Bool) -> [HRSample] {
        if background && workouts { return samples }
        return samples.filter { $0.inWorkout ? workouts : background }
    }
}

extension RandomAccessCollection where Element == HRSample {
    /// Gennemsnitlig samplingfrekvens i Hz: antal intervaller / tidsspænd (kræver sorterede målinger).
    var samplingRateHz: Double? {
        guard count >= 2, let first = self.first, let last = self.last, last.date > first.date else { return nil }
        return Double(count - 1) / last.date.timeIntervalSince(first.date)
    }
}

extension Array where Element == HRSample {
    /// Første indeks med dato ≥ `date` (binær søgning; målingerne er sorteret).
    func firstIndex(atOrAfter date: Date) -> Int {
        var lo = 0, hi = count
        while lo < hi {
            let mid = (lo + hi) / 2
            if self[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Målingerne i [from, to] uden at gennemløbe hele arrayet.
    func slice(from: Date, to: Date) -> ArraySlice<HRSample> {
        let a = firstIndex(atOrAfter: from)
        var b = firstIndex(atOrAfter: to)
        while b < count && self[b].date == to { b += 1 }
        return self[a..<Swift.max(a, b)]
    }
}

struct HeartStats: Equatable {
    let min: Int, avg: Int, max: Int

    init(min: Int, avg: Int, max: Int) {
        self.min = min; self.avg = avg; self.max = max
    }

    init?(_ samples: [HRSample]) {
        guard !samples.isEmpty else { return nil }
        let v = samples.map(\.bpm)
        min = Int(v.min()!.rounded())
        max = Int(v.max()!.rounded())
        avg = Int((v.reduce(0, +) / Double(v.count)).rounded())
    }
}

/// Samler værdier fra en serie-forespørgsel (HealthKit kalder tilbage fra en baggrundstråd).
private final class SeriesBox: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private(set) var values: [(date: Date, bpm: Double)] = []

    func append(date: Date, bpm: Double) {
        lock.lock(); values.append((date, bpm)); lock.unlock()
    }

    /// Kører kun første gang (så fortsættelsen aldrig genoptages to gange).
    func finish(_ body: () -> Void) {
        lock.lock(); let first = !finished; finished = true; lock.unlock()
        if first { body() }
    }
}

@Observable @MainActor
final class HealthManager {
    private let store = HKHealthStore()
    private let hrType = HKQuantityType(.heartRate)
    private let exerciseType = HKQuantityType(.appleExerciseTime)
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    var periodSamples: [HRSample] = [] { didSet { refreshShown() } }

    /// Standardværdier for alle indstillinger (bruges ved nulstilling).
    enum Defaults {
        static let includeBackground = true
        static let includeWorkouts = true
        static let zoneModel = ZoneModel.two
        static let maxHRSource = MaxHRSource.age
        static let onlyWhenActive = true
        static let maxGapSeconds = 300
        /// Højeste tilladte hul uden for workouts (længere giver ikke mening).
        static let maxGapLimit = 600
        static let workoutGaps = ActiveMinutes.WorkoutGaps.betweenMeasurements
        static let interpolation = ActiveMinutes.Interpolation.linear
        static let minutesSource = ActiveMinutes.Source.heartRate
        static let showComparison = false
        static let activitySource = ActiveMinutes.ActivitySource.either
        /// Korte huller mellem aktive målinger, der udfyldes (sekunder; 0 = fra).
        /// Standard: »Aktiv, træningsring og korte pauser« på 300 s (5 min).
        static let activeBridgeSeconds = 300
        /// Længste pause, der udfyldes med »Aktiv, træningsring og korte pauser«.
        static let pauseSeconds = 300
        static let watchPeriod = SummaryPeriod.thisWeek
        static let pauseLimit = 600
        static let activityMode = ActiveMinutes.ActivityMode.withPauses
        static let weeklyGoal = 150
        static let age = 40
    }

    /// Globale indstillinger: hvilke målinger der tæller og vises i pulsgrafen.
    var includeBackground: Bool = UserDefaults.standard.object(forKey: "includeBackground") as? Bool ?? Defaults.includeBackground {
        didSet { UserDefaults.standard.set(includeBackground, forKey: "includeBackground"); refreshShown() }
    }
    var includeWorkouts: Bool = UserDefaults.standard.object(forKey: "includeWorkouts") as? Bool ?? Defaults.includeWorkouts {
        didSet { UserDefaults.standard.set(includeWorkouts, forKey: "includeWorkouts"); refreshShown() }
    }
    /// 2 zoner (AHA) eller 5 zoner.
    var zoneModel: ZoneModel = ZoneModel(rawValue: UserDefaults.standard.string(forKey: "zoneModel") ?? "") ?? Defaults.zoneModel {
        didSet { UserDefaults.standard.set(zoneModel.rawValue, forKey: "zoneModel") }
    }
    /// Grænser (andel af maks-puls) og faktorer pr. zone – gemt for hver model for sig.
    var zonePercents: [Double] {
        get { stored("zonePercents.\(zoneModel.rawValue)", count: zoneModel.names.count) ?? zoneModel.defaultPercents }
        set { UserDefaults.standard.set(newValue, forKey: "zonePercents.\(zoneModel.rawValue)"); zonesVersion += 1 }
    }
    var zoneWeights: [Double] {
        get { stored("zoneWeights.\(zoneModel.rawValue)", count: zoneModel.names.count) ?? zoneModel.defaultWeights }
        set { UserDefaults.standard.set(newValue, forKey: "zoneWeights.\(zoneModel.rawValue)"); zonesVersion += 1 }
    }
    /// Får SwiftUI til at opdatere, når grænser/faktorer ændres (de ligger i UserDefaults).
    private var zonesVersion = 0
    private func stored(_ key: String, count: Int) -> [Double]? {
        _ = zonesVersion
        guard let a = UserDefaults.standard.array(forKey: key) as? [Double], a.count == count else { return nil }
        return a
    }

    /// Perioden, som komplikationer og ur-app viser (synkroniseres til uret).
    var watchPeriod: SummaryPeriod = UserDefaults.standard.string(forKey: "watchPeriod")
        .flatMap(SummaryPeriod.init(rawValue:)) ?? Defaults.watchPeriod {
        didSet { UserDefaults.standard.set(watchPeriod.rawValue, forKey: "watchPeriod") }
    }

    /// Mål for aktive minutter pr. uge (AHA: 150). Skaleres til den valgte periode.
    var weeklyGoal: Int = UserDefaults.standard.object(forKey: "weeklyGoal") as? Int ?? Defaults.weeklyGoal {
        didSet { UserDefaults.standard.set(weeklyGoal, forKey: "weeklyGoal") }
    }

    /// Aktive minutter tæller kun, når Apple Watch vurderer, at man bevæger sig.
    var onlyWhenActive: Bool = UserDefaults.standard.object(forKey: "onlyWhenActive") as? Bool ?? Defaults.onlyWhenActive {
        didSet { UserDefaults.standard.set(onlyWhenActive, forKey: "onlyWhenActive") }
    }

    /// Hvordan huller i målingerne behandles under workouts.
    var workoutGaps: ActiveMinutes.WorkoutGaps = HealthManager.storedWorkoutGaps() {
        didSet { UserDefaults.standard.set(workoutGaps.rawValue, forKey: "workoutGaps"); refreshShown() }
    }

    /// Læser valget – og oversætter de gamle kontakter ("Tæl hele workouten med" / "Stræk").
    nonisolated private static func storedWorkoutGaps() -> ActiveMinutes.WorkoutGaps {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: "workoutGaps"), let v = ActiveMinutes.WorkoutGaps(rawValue: raw) { return v }
        if d.bool(forKey: "extendWorkouts") { return .wholeWorkout }
        if let fill = d.object(forKey: "fillWorkoutGaps") as? Bool, !fill { return .sameLimit }
        return Defaults.workoutGaps
    }

    /// Hvordan pulsen mellem to målinger regnes.
    var interpolation: ActiveMinutes.Interpolation =
        ActiveMinutes.Interpolation(rawValue: UserDefaults.standard.string(forKey: "interpolation") ?? "")
        ?? Defaults.interpolation {
        didSet { UserDefaults.standard.set(interpolation.rawValue, forKey: "interpolation") }
    }

    /// Hvad der afgør "aktiv" med "Kun når aktiv".
    var activitySource: ActiveMinutes.ActivitySource =
        ActiveMinutes.ActivitySource(rawValue: UserDefaults.standard.string(forKey: "activitySource") ?? "")
        ?? Defaults.activitySource {
        didSet { UserDefaults.standard.set(activitySource.rawValue, forKey: "activitySource") }
    }

    /// Huller på højst så mange sekunder mellem to aktive målinger tæller som aktive (0 = fra).
    /// (Sekunder; tidligere gemt i minutter under "activeBridgeMinutes".)
    var activeBridgeSeconds: Int = UserDefaults.standard.object(forKey: "activeBridgeSeconds") as? Int
        ?? (UserDefaults.standard.object(forKey: "activeBridgeMinutes") as? Int).map { $0 * 60 }
        ?? Defaults.activeBridgeSeconds {
        didSet { UserDefaults.standard.set(activeBridgeSeconds, forKey: "activeBridgeSeconds") }
    }

    /// Længste pause for »med pauser« (huskes, også når en anden tilstand er valgt).
    var pauseSeconds: Int = UserDefaults.standard.object(forKey: "pauseSeconds") as? Int
        ?? (UserDefaults.standard.object(forKey: "pauseMinutes") as? Int).map { $0 * 60 }
        ?? (UserDefaults.standard.object(forKey: "activeBridgeMinutes") as? Int).flatMap { $0 > 0 ? $0 * 60 : nil }
        ?? Defaults.pauseSeconds {
        didSet {
            let clamped = min(max(pauseSeconds, 1), Defaults.pauseLimit)
            if clamped != pauseSeconds { pauseSeconds = clamped }   // (kalder ikke didSet igen)
            UserDefaults.standard.set(pauseSeconds, forKey: "pauseSeconds")
            if activeBridgeSeconds > 0 { activeBridgeSeconds = pauseSeconds }
        }
    }

    /// Den samlede indstilling for, hvornår baggrundspuls tæller.
    var activityMode: ActiveMinutes.ActivityMode {
        get {
            if !onlyWhenActive { return .always }
            if activeBridgeSeconds > 0 { return activitySource == .watchMotion ? .watchWithPauses : .withPauses }
            return activitySource == .watchMotion ? .watch : .watchOrRing
        }
        set {
            switch newValue {
            case .always:
                onlyWhenActive = false; activeBridgeSeconds = 0
            case .watch:
                onlyWhenActive = true; activitySource = .watchMotion; activeBridgeSeconds = 0
            case .watchWithPauses:
                onlyWhenActive = true; activitySource = .watchMotion; activeBridgeSeconds = max(pauseSeconds, 1)
            case .watchOrRing:
                onlyWhenActive = true; activitySource = .either; activeBridgeSeconds = 0
            case .withPauses:
                onlyWhenActive = true; activitySource = .either; activeBridgeSeconds = max(pauseSeconds, 1)
            }
        }
    }

    /// Indstillingerne for aktive minutter samlet ét sted.
    var minutesConfig: ActiveMinutes.Config {
        ActiveMinutes.Config(zones: zones, requireActive: onlyWhenActive, fillWorkoutGaps: workoutGaps != .sameLimit,
                             maxGap: maxGap, interpolation: interpolation, activitySource: activitySource,
                             activeBridge: TimeInterval(max(activeBridgeSeconds, 0)))
    }

    /// Længste hul mellem to målinger uden for workouts, der tælles med (1–600 sekunder).
    var maxGapSeconds: Int = min(max(UserDefaults.standard.object(forKey: "maxGapSeconds") as? Int ?? Defaults.maxGapSeconds, 1), Defaults.maxGapLimit) {
        didSet { UserDefaults.standard.set(maxGapSeconds, forKey: "maxGapSeconds") }
    }
    var maxGap: TimeInterval { TimeInterval(min(max(maxGapSeconds, 1), Defaults.maxGapLimit)) }

    /// Heart Minutes regnes ud fra puls (zoner × vægt) eller træningsringsminutter.
    var minutesSource: ActiveMinutes.Source =
        ActiveMinutes.Source(rawValue: UserDefaults.standard.string(forKey: "minutesSource") ?? "") ?? Defaults.minutesSource {
        didSet { UserDefaults.standard.set(minutesSource.rawValue, forKey: "minutesSource"); refreshShown() }
    }
    /// Vis den anden kilde som stiplet linje i minut-grafen.
    var showComparison: Bool = UserDefaults.standard.object(forKey: "showComparison") as? Bool ?? Defaults.showComparison {
        didSet { UserDefaults.standard.set(showComparison, forKey: "showComparison") }
    }
    /// træningsringsminutter i perioden, kumulativt.
    private(set) var applePoints: [ActiveMinutes.Point] = []


    /// Periodens målinger efter indstillingerne (gemt, så de ikke filtreres igen ved hver visning).
    private(set) var shownSamples: [HRSample] = []
    /// Målingerne aktive minutter regnes på: de viste, evt. strakt ud til hele workouten.
    private(set) var minuteSamples: [HRSample] = []
    /// Periodens workouts.
    private(set) var periodWorkouts: [DateInterval] = []
    /// Den periode, de viste data hører til. Skiftes samtidig med data, så tal, mål og grafer
    /// ikke blander den gamle periodes målinger med den nyes tidsakse.
    private(set) var loadedInterval: DateInterval?
    /// Workout-typen (fra Sundhed) for hver workout i perioden, efter starttidspunkt.
    private(set) var workoutTypes: [Date: HKWorkoutActivityType] = [:]
    /// Baggrundsmålinger i perioden uden aktiv/i ro-markering.
    private(set) var unmarked = HRSample.UnmarkedInfo(count: 0, backgroundCount: 0, sources: [])

    /// Kilder, brugeren har valgt at ignorere i beskeden om manglende markering.
    var ignoredUnmarkedSources: [String] = UserDefaults.standard.stringArray(forKey: "ignoredUnmarkedSources") ?? [] {
        didSet { UserDefaults.standard.set(ignoredUnmarkedSources, forKey: "ignoredUnmarkedSources") }
    }

    /// Vis beskeden, når "Kun når aktiv" sorterer en betydelig del af baggrundsmålingerne fra,
    /// fordi de ikke kommer fra Apple Watch.
    var showUnmarkedHint: Bool {
        minutesSource == .heartRate && onlyWhenActive && activitySource == .watchMotion && includeBackground
            && unmarked.count >= 50 && unmarked.fraction >= 0.2
            && !Set(unmarked.sources).isSubset(of: Set(ignoredUnmarkedSources))
    }

    func ignoreUnmarkedSources() {
        ignoredUnmarkedSources = Array(Set(ignoredUnmarkedSources).union(unmarked.sources)).sorted()
    }

    private func refreshShown() {
        unmarked = HRSample.unmarkedBackground(periodSamples)
        // Med Træningsring bruges målingerne ikke i beregningen – så vises alle i pulsgrafen.
        let ring = minutesSource == .appleExercise
        shownSamples = HRSample.filtered(periodSamples, background: ring || includeBackground,
                                         workouts: ring || includeWorkouts)
        minuteSamples = workoutGaps == .wholeWorkout
            ? ActiveMinutes.extendingWorkouts(shownSamples, periodWorkouts) : shownSamples
    }
    var errorMessage: String?
    /// Sidste hentning fra Sundhed fejlede eller blev afbrudt (data er ufuldstændige).
    private(set) var loadFailed = false

    /// Alder bruges til maks-puls (220 − alder). Gemmes; hentes fra Sundhed første gang.
    var age: Int = UserDefaults.standard.object(forKey: "age") as? Int ?? Defaults.age {
        didSet { UserDefaults.standard.set(age, forKey: "age") }
    }

    /// Maks-puls ud fra alder (220 − alder) eller indtastet.
    var maxHRSource: MaxHRSource = MaxHRSource(rawValue: UserDefaults.standard.string(forKey: "maxHRSource") ?? "") ?? Defaults.maxHRSource {
        didSet { UserDefaults.standard.set(maxHRSource.rawValue, forKey: "maxHRSource") }
    }
    /// Indtastet maks-puls (fx målt ved en test).
    var manualMaxHR: Int = UserDefaults.standard.object(forKey: "manualMaxHR") as? Int ?? 180 {
        didSet { UserDefaults.standard.set(manualMaxHR, forKey: "manualMaxHR") }
    }
    /// Maks-pulsen, der bruges.
    var maxHR: Double { maxHRSource == .age ? HeartZones.maxHR(age: age) : Double(manualMaxHR) }

    /// Alder fra Sundhed (fødselsdato), hvis den kan læses – standard for "Alder".
    private(set) var healthAge: Int?
    var defaultAge: Int { healthAge ?? Defaults.age }
    /// Standard for indtastet maks-puls: ud fra alderen.
    var defaultMaxHR: Int { Int(HeartZones.maxHR(age: age)) }

    /// Sætter alle indstillinger tilbage til standard.
    func resetAll() {
        includeBackground = Defaults.includeBackground
        includeWorkouts = Defaults.includeWorkouts
        age = defaultAge
        manualMaxHR = defaultMaxHR
        maxHRSource = Defaults.maxHRSource
        for model in ZoneModel.allCases {
            UserDefaults.standard.removeObject(forKey: "zonePercents.\(model.rawValue)")
            UserDefaults.standard.removeObject(forKey: "zoneWeights.\(model.rawValue)")
        }
        zoneModel = Defaults.zoneModel
        zonesVersion += 1
        onlyWhenActive = Defaults.onlyWhenActive
        maxGapSeconds = Defaults.maxGapSeconds
        workoutGaps = Defaults.workoutGaps
        interpolation = Defaults.interpolation
        weeklyGoal = Defaults.weeklyGoal
        ignoredUnmarkedSources = []
        minutesSource = Defaults.minutesSource
        showComparison = Defaults.showComparison
        activitySource = Defaults.activitySource
        activeBridgeSeconds = Defaults.activeBridgeSeconds
        pauseSeconds = Defaults.pauseSeconds
        watchPeriod = Defaults.watchPeriod
    }

    var zones: HeartZones {
        HeartZones(maxHR: maxHR, model: zoneModel, percents: zonePercents, weights: zoneWeights)
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Sundhedsdata er ikke tilgængelige på denne enhed."
            return
        }
        do {
            try await store.requestAuthorization(
                toShare: [],
                read: [hrType, exerciseType, .workoutType(), HKCharacteristicType(.dateOfBirth)])
        } catch { errorMessage = error.localizedDescription }
        loadAgeFromHealthIfNeeded()
    }

    private func loadAgeFromHealthIfNeeded() {
        guard let components = try? store.dateOfBirthComponents(),
              let birth = Calendar.current.date(from: components),
              let years = Calendar.current.dateComponents([.year], from: birth, to: .now).year
        else { return }
        healthAge = years
        if UserDefaults.standard.object(forKey: "age") == nil { age = years }
    }

    /// Antal målinger i perioden, der kom fra serier (én post i Sundhed med mange pulsværdier).
    private(set) var seriesValueCount = 0

    func heartRates(from start: Date, to end: Date) async -> [HRSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: hrType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        do {
            var result: [HRSample] = []
            var fromSeries = 0
            for sample in try await query.result(for: store) {
                let motion = MotionContext(sample.metadata)
                // Apple Watch gemmer tit workout-puls som en serie: én post med mange værdier.
                // Uden at pakke den ud får man kun én værdi (og mister fx toppe).
                if let discrete = sample as? HKDiscreteQuantitySample, discrete.count > 1 {
                    let values = try await seriesValues(of: sample)
                    fromSeries += values.count
                    let source = sample.sourceRevision.source.name
                    result += values.map { HRSample(date: $0.date, bpm: $0.bpm, motion: motion, source: source) }
                } else {
                    result.append(HRSample(date: sample.startDate,
                                           bpm: sample.quantity.doubleValue(for: bpmUnit), motion: motion,
                                           source: sample.sourceRevision.source.name))
                }
            }
            seriesValueCount = fromSeries
            return result.sorted { $0.date < $1.date }
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
            return []
        }
    }

    /// De enkelte pulsværdier i en serie-post.
    private func seriesValues(of sample: HKQuantitySample) async throws -> [(date: Date, bpm: Double)] {
        try await withCheckedThrowingContinuation { continuation in
            let box = SeriesBox()
            let query = HKQuantitySeriesSampleQuery(sample: sample) { _, quantity, date, done, error in
                if let error {
                    box.finish { continuation.resume(throwing: error) }
                    return
                }
                if let quantity, let date {
                    let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    box.append(date: date, bpm: bpm)
                }
                if done { box.finish { continuation.resume(returning: box.values) } }
            }
            store.execute(query)
        }
    }

    /// Henter puls for perioden og markerer målinger, der ligger under en workout.
    func loadPeriod(_ interval: DateInterval) async {
        loadFailed = false
        let samples = await heartRates(from: interval.start, to: interval.end)
        let workoutIntervals = await workoutIntervals(from: interval.start, to: interval.end)
        let exercise = await exerciseSamples(from: interval.start, to: interval.end)
        // Afbrudt (fx når iOS stopper en baggrundsopdatering, eller der er valgt en ny periode):
        // data er ufuldstændige eller forældede, så de vises ikke.
        if Task.isCancelled { loadFailed = true; return }
        loadedInterval = interval
        applePoints = ActiveMinutes.cumulativeExercise(exercise.map { (end: $0.end, minutes: $0.minutes) },
                                                       start: interval.start)
        periodWorkouts = workoutIntervals
        periodSamples = HRSample.markingExercise(HRSample.markingWorkouts(samples, workoutIntervals),
                                                 exercise.map(\.interval))
    }

    /// træningsringsminutter (den grønne ring) i perioden, lagt sammen over tid.
    func exerciseMinutes(from start: Date, to end: Date) async -> [ActiveMinutes.Point] {
        ActiveMinutes.cumulativeExercise(
            await exerciseSamples(from: start, to: end).map { (end: $0.end, minutes: $0.minutes) }, start: start)
    }

    /// træningsringsminutter som enkelte tidsrum (normalt ét pr. minut).
    func exerciseSamples(from start: Date, to end: Date) async -> [(interval: DateInterval, end: Date, minutes: Double)] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: exerciseType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples: [HKQuantitySample]
        do { samples = try await query.result(for: store) } catch { loadFailed = true; return [] }
        return samples.map {
            (DateInterval(start: $0.startDate, end: max($0.endDate, $0.startDate)), $0.endDate,
             $0.quantity.doubleValue(for: .minute()))
        }
    }

    /// Tidsrummene for de workouts, der overlapper perioden.
    func workoutIntervals(from start: Date, to end: Date) async -> [DateInterval] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)])
        do {
            let workouts = try await query.result(for: store)
            for w in workouts { workoutTypes[w.startDate] = w.workoutActivityType }
            return workouts.map {
                DateInterval(start: $0.startDate, end: max($0.endDate, $0.startDate))
            }
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
            return []
        }
    }
}

extension HealthManager {
    /// Ugens Heart Minutes til komplikation og widgets, regnet med de gemte indstillinger.
    /// `nil`, hvis Sundhed ikke kunne læses (så de gemte tal ikke overskrives med 0).
    static func weekSummary(now: Date = .now) async -> ComplicationData? {
        await summary(for: .thisWeek, now: now)
    }

    /// Heart Minutes for alle widget-perioder på én gang: data hentes én gang for det samlede
    /// tidsrum og deles derefter op (hurtigere end at hente hver periode for sig).
    static func summaries(now: Date = .now) async -> [SummaryPeriod: ComplicationData] {
        let intervals = Dictionary(uniqueKeysWithValues: SummaryPeriod.allCases.map { ($0, $0.interval(now: now)) })
        guard let start = intervals.values.map(\.start).min(),
              let end = intervals.values.map(\.end).max() else { return [:] }
        let health = HealthManager()
        await health.loadPeriod(DateInterval(start: start, end: end))
        // Fejl eller afbrudt hentning: gem ingenting, hellere gamle tal end 0.
        guard !health.loadFailed else { return [:] }
        var result: [SummaryPeriod: ComplicationData] = [:]
        for (period, interval) in intervals {
            let points: [ActiveMinutes.Point]
            var zoneSlices: [ZoneSlice]? = nil
            if health.minutesSource == .appleExercise {
                points = ActiveMinutes.rebased(health.applePoints, to: interval)
            } else {
                let slice = Array(health.minuteSamples.slice(from: interval.start, to: interval.end))
                let r = ActiveMinutes(slice, config: health.minutesConfig)
                points = r.points
                zoneSlices = health.zones.slices(r.zoneMinutes)
            }
            result[period] = ComplicationData(
                minutes: points.last?.total ?? 0,
                goal: period.goal(weekly: Double(health.weeklyGoal), now: now),
                updated: now,
                points: ComplicationData.reduced(points.map { .init(t: $0.date, v: $0.total) }),
                zones: zoneSlices)
        }
        return result
    }

    /// Heart Minutes for en periode (uge, dag, 7 dage) til widgets.
    static func summary(for period: SummaryPeriod, now: Date = .now) async -> ComplicationData? {
        let health = HealthManager()
        await health.loadPeriod(period.interval(now: now))
        guard !health.loadFailed else { return nil }
        let apple = health.minutesSource == .appleExercise
        let points = apple ? health.applePoints
            : ActiveMinutes(health.minuteSamples, config: health.minutesConfig).points
        return ComplicationData(
            minutes: points.last?.total ?? 0,
            goal: period.goal(weekly: Double(health.weeklyGoal), now: now),
            updated: now,
            points: ComplicationData.reduced(points.map { .init(t: $0.date, v: $0.total) }))
    }
}
