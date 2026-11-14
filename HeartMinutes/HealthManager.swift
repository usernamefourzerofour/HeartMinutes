import HealthKit
import Observation

/// Apple's own judgement of whether you were moving when the heart rate was measured
/// (HKMetadataKeyHeartRateMotionContext on Apple Watch measurements).
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
        case .unknown: String(localized: "Unknown")
        case .sedentary: String(localized: "Resting")
        case .active: String(localized: "Active")
        }
    }
}

struct HRSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let bpm: Double
    /// Measured during a workout (otherwise a background measurement).
    var inWorkout = false
    /// Whether Apple judged you active or resting.
    var motion: MotionContext = .unknown
    /// Start of the workout the measurement belongs to (so two measurements can be recognised as the same workout).
    var workoutStart: Date? = nil
    /// The source in Health (e.g. "my Apple Watch" or another app/device).
    var source: String? = nil
    /// Measured in a minute that counts in the Exercise ring (the green ring).
    var inExercise = false
    /// Lies in a short gap between two active measurements and therefore counts as active ("Fill short gaps").
    var bridgedActive = false

    /// The same measurement at another time (used to stretch a workout's measurements).
    func copy(at date: Date) -> HRSample {
        var s = HRSample(date: date, bpm: bpm, inWorkout: inWorkout, motion: motion)
        s.workoutStart = workoutStart
        s.source = source
        s.inExercise = inExercise
        s.bridgedActive = bridgedActive
        return s
    }

    /// Background measurements without an active/resting marking (it only comes from Apple Watch).
    struct UnmarkedInfo: Equatable {
        let count: Int
        let backgroundCount: Int
        /// The sources, most measurements first.
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
                perSource[s.source ?? String(localized: "Unknown source"), default: 0] += 1
            }
        }
        let sources = perSource.sorted { $0.value > $1.value }.map(\.key)
        return UnmarkedInfo(count: unmarked, backgroundCount: background, sources: sources)
    }

    /// Marks the measurements that fall within one of the workout periods.
    static func markingWorkouts(_ samples: [HRSample], _ workouts: [DateInterval]) -> [HRSample] {
        guard !workouts.isEmpty else { return samples }
        // Both are sorted by time: walk through once instead of checking every workout for each measurement.
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

    /// Marks measurements that lie in a minute that counts in the Exercise ring (the green ring).
    static func markingExercise(_ samples: [HRSample], _ minutes: [DateInterval]) -> [HRSample] {
        guard !minutes.isEmpty else { return samples }
        let sorted = minutes.sorted { $0.start < $1.start }
        var i = 0
        return samples.map { s in
            var s = s
            // Half-open minutes [start, end), so a measurement exactly on a minute boundary belongs to only one.
            while i < sorted.count && sorted[i].end <= s.date { i += 1 }
            if i < sorted.count && sorted[i].start <= s.date { s.inExercise = true }
            return s
        }
    }

    /// A pause where the line breaks (e.g. between two workouts when background is off).
    static let lineBreakGap: TimeInterval = 3600

    /// Series number per continuous stretch of the same type, so the line changes colour without connecting background
    /// and workout – and breaks at gaps over an hour.
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

    /// Filters by the settings for background and workout measurements.
    static func filtered(_ samples: [HRSample], background: Bool, workouts: Bool) -> [HRSample] {
        if background && workouts { return samples }
        return samples.filter { $0.inWorkout ? workouts : background }
    }
}

extension RandomAccessCollection where Element == HRSample {
    /// Average sampling rate in Hz: number of intervals / time span (requires sorted measurements).
    var samplingRateHz: Double? {
        guard count >= 2, let first = self.first, let last = self.last, last.date > first.date else { return nil }
        return Double(count - 1) / last.date.timeIntervalSince(first.date)
    }
}

extension Array where Element == HRSample {
    /// First index with date ≥ `date` (binary search; the measurements are sorted).
    func firstIndex(atOrAfter date: Date) -> Int {
        var lo = 0, hi = count
        while lo < hi {
            let mid = (lo + hi) / 2
            if self[mid].date < date { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// The measurements in [from, to] without walking the whole array.
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

/// Collects values from a series query (HealthKit calls back from a background thread).
private final class SeriesBox: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false
    private(set) var values: [(date: Date, bpm: Double)] = []

    func append(date: Date, bpm: Double) {
        lock.lock(); values.append((date, bpm)); lock.unlock()
    }

    /// Only runs the first time (so the continuation is never resumed twice).
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

    /// Default values for all settings (used when resetting).
    enum Defaults {
        static let includeBackground = true
        static let includeWorkouts = true
        static let zoneModel = ZoneModel.two
        static let maxHRSource = MaxHRSource.age
        static let onlyWhenActive = true
        static let maxGapSeconds = 300
        /// Highest allowed gap outside workouts (longer makes no sense).
        static let maxGapLimit = 600
        static let workoutGaps = ActiveMinutes.WorkoutGaps.betweenMeasurements
        static let interpolation = ActiveMinutes.Interpolation.linear
        static let showComparison = false
        static let activitySource = ActiveMinutes.ActivitySource.either
        /// Short gaps between active measurements that are filled (seconds; 0 = off). Default: »Active, Exercise ring
        /// and short pauses« at 300 s (5 min).
        static let activeBridgeSeconds = 300
        /// Longest pause that is filled with »Active, Exercise ring and short pauses«.
        static let pauseSeconds = 300
        static let watchPeriod = SummaryPeriod.thisWeek
        static let pauseLimit = 600
        static let activityMode = ActiveMinutes.ActivityMode.withPauses
        static let weeklyGoal = 150
        static let age = 40
    }

    /// Global settings: which measurements count and are shown in the heart rate chart.
    var includeBackground: Bool = UserDefaults.standard.object(forKey: "includeBackground") as? Bool ?? Defaults.includeBackground {
        didSet { UserDefaults.standard.set(includeBackground, forKey: "includeBackground"); refreshShown() }
    }
    var includeWorkouts: Bool = UserDefaults.standard.object(forKey: "includeWorkouts") as? Bool ?? Defaults.includeWorkouts {
        didSet { UserDefaults.standard.set(includeWorkouts, forKey: "includeWorkouts"); refreshShown() }
    }
    /// 2 zones (AHA) or 5 zones.
    var zoneModel: ZoneModel = ZoneModel(rawValue: UserDefaults.standard.string(forKey: "zoneModel") ?? "") ?? Defaults.zoneModel {
        didSet { UserDefaults.standard.set(zoneModel.rawValue, forKey: "zoneModel") }
    }
    /// Limits (fraction of max heart rate) and factors per zone – stored separately for each model.
    var zonePercents: [Double] {
        get { stored("zonePercents.\(zoneModel.rawValue)", count: zoneModel.names.count) ?? zoneModel.defaultPercents }
        set { UserDefaults.standard.set(newValue, forKey: "zonePercents.\(zoneModel.rawValue)"); zonesVersion += 1 }
    }
    var zoneWeights: [Double] {
        get { stored("zoneWeights.\(zoneModel.rawValue)", count: zoneModel.names.count) ?? zoneModel.defaultWeights }
        set { UserDefaults.standard.set(newValue, forKey: "zoneWeights.\(zoneModel.rawValue)"); zonesVersion += 1 }
    }
    /// Makes SwiftUI update when limits/factors change (they live in UserDefaults).
    private var zonesVersion = 0
    private func stored(_ key: String, count: Int) -> [Double]? {
        _ = zonesVersion
        guard let a = UserDefaults.standard.array(forKey: key) as? [Double], a.count == count else { return nil }
        return a
    }

    /// The period shown by the complications and the watch app (synced to the watch).
    var watchPeriod: SummaryPeriod = UserDefaults.standard.string(forKey: "watchPeriod")
        .flatMap(SummaryPeriod.init(rawValue:)) ?? Defaults.watchPeriod {
        didSet { UserDefaults.standard.set(watchPeriod.rawValue, forKey: "watchPeriod") }
    }

    /// Goal for active minutes per week (AHA: 150). Scaled to the selected period.
    var weeklyGoal: Int = UserDefaults.standard.object(forKey: "weeklyGoal") as? Int ?? Defaults.weeklyGoal {
        didSet { UserDefaults.standard.set(weeklyGoal, forKey: "weeklyGoal") }
    }

    /// Active minutes only count when Apple Watch judges that you are moving.
    var onlyWhenActive: Bool = UserDefaults.standard.object(forKey: "onlyWhenActive") as? Bool ?? Defaults.onlyWhenActive {
        didSet { UserDefaults.standard.set(onlyWhenActive, forKey: "onlyWhenActive") }
    }

    /// How gaps in the measurements are handled during workouts.
    var workoutGaps: ActiveMinutes.WorkoutGaps = HealthManager.storedWorkoutGaps() {
        didSet { UserDefaults.standard.set(workoutGaps.rawValue, forKey: "workoutGaps"); refreshShown() }
    }

    /// Reads the choice – and translates the old switches ("Count the whole workout" / "Stretch").
    nonisolated private static func storedWorkoutGaps() -> ActiveMinutes.WorkoutGaps {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: "workoutGaps"), let v = ActiveMinutes.WorkoutGaps(rawValue: raw) { return v }
        if d.bool(forKey: "extendWorkouts") { return .wholeWorkout }
        if let fill = d.object(forKey: "fillWorkoutGaps") as? Bool, !fill { return .sameLimit }
        return Defaults.workoutGaps
    }

    /// How the heart rate between two measurements is calculated.
    var interpolation: ActiveMinutes.Interpolation =
        ActiveMinutes.Interpolation(rawValue: UserDefaults.standard.string(forKey: "interpolation") ?? "")
        ?? Defaults.interpolation {
        didSet { UserDefaults.standard.set(interpolation.rawValue, forKey: "interpolation") }
    }

    /// What decides "active" with "Only when active".
    var activitySource: ActiveMinutes.ActivitySource =
        ActiveMinutes.ActivitySource(rawValue: UserDefaults.standard.string(forKey: "activitySource") ?? "")
        ?? Defaults.activitySource {
        didSet { UserDefaults.standard.set(activitySource.rawValue, forKey: "activitySource") }
    }

    /// Gaps of at most this many seconds between two active measurements count as active (0 = off). (Seconds;
    /// previously stored in minutes as "activeBridgeMinutes".)
    var activeBridgeSeconds: Int = UserDefaults.standard.object(forKey: "activeBridgeSeconds") as? Int
        ?? (UserDefaults.standard.object(forKey: "activeBridgeMinutes") as? Int).map { $0 * 60 }
        ?? Defaults.activeBridgeSeconds {
        didSet { UserDefaults.standard.set(activeBridgeSeconds, forKey: "activeBridgeSeconds") }
    }

    /// Longest pause for »with pauses« (remembered even when another mode is selected).
    var pauseSeconds: Int = UserDefaults.standard.object(forKey: "pauseSeconds") as? Int
        ?? (UserDefaults.standard.object(forKey: "pauseMinutes") as? Int).map { $0 * 60 }
        ?? (UserDefaults.standard.object(forKey: "activeBridgeMinutes") as? Int).flatMap { $0 > 0 ? $0 * 60 : nil }
        ?? Defaults.pauseSeconds {
        didSet {
            let clamped = min(max(pauseSeconds, 1), Defaults.pauseLimit)
            if clamped != pauseSeconds { pauseSeconds = clamped }   // (doesn't call didSet again)
            UserDefaults.standard.set(pauseSeconds, forKey: "pauseSeconds")
            if activeBridgeSeconds > 0 { activeBridgeSeconds = pauseSeconds }
        }
    }

    /// The combined setting for when background heart rate counts.
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

    /// The settings for active minutes in one place.
    var minutesConfig: ActiveMinutes.Config {
        ActiveMinutes.Config(zones: zones, requireActive: onlyWhenActive, fillWorkoutGaps: workoutGaps != .sameLimit,
                             maxGap: maxGap, interpolation: interpolation, activitySource: activitySource,
                             activeBridge: TimeInterval(max(activeBridgeSeconds, 0)))
    }

    /// Longest gap between two measurements outside workouts that counts (1–600 seconds).
    var maxGapSeconds: Int = min(max(UserDefaults.standard.object(forKey: "maxGapSeconds") as? Int ?? Defaults.maxGapSeconds, 1), Defaults.maxGapLimit) {
        didSet { UserDefaults.standard.set(maxGapSeconds, forKey: "maxGapSeconds") }
    }
    var maxGap: TimeInterval { TimeInterval(min(max(maxGapSeconds, 1), Defaults.maxGapLimit)) }

    /// Show the Exercise minutes as a line in the minutes chart for comparison.
    var showComparison: Bool = UserDefaults.standard.object(forKey: "showComparison") as? Bool ?? Defaults.showComparison {
        didSet { UserDefaults.standard.set(showComparison, forKey: "showComparison") }
    }
    /// Exercise minutes in the period, cumulative.
    private(set) var applePoints: [ActiveMinutes.Point] = []


    /// The period's measurements after the settings (stored so they aren't filtered again on every render).
    private(set) var shownSamples: [HRSample] = []
    /// The measurements active minutes are calculated from: the shown ones, possibly stretched to the whole workout.
    private(set) var minuteSamples: [HRSample] = []
    /// The period's workouts.
    private(set) var periodWorkouts: [DateInterval] = []
    /// The period the shown data belongs to. Changes together with the data, so numbers, goal and charts don't mix the
    /// old period's measurements with the new time axis.
    private(set) var loadedInterval: DateInterval?
    /// The workout type (from Health) for each workout in the period, by start time.
    private(set) var workoutTypes: [Date: HKWorkoutActivityType] = [:]
    /// Background measurements in the period without an active/resting marking.
    private(set) var unmarked = HRSample.UnmarkedInfo(count: 0, backgroundCount: 0, sources: [])

    /// Sources the user chose to ignore in the message about the missing marking.
    var ignoredUnmarkedSources: [String] = UserDefaults.standard.stringArray(forKey: "ignoredUnmarkedSources") ?? [] {
        didSet { UserDefaults.standard.set(ignoredUnmarkedSources, forKey: "ignoredUnmarkedSources") }
    }

    /// Show the message when "Only when active" filters out a significant part of the background measurements because
    /// they don't come from Apple Watch.
    var showUnmarkedHint: Bool {
        onlyWhenActive && activitySource == .watchMotion && includeBackground
            && unmarked.count >= 50 && unmarked.fraction >= 0.2
            && !Set(unmarked.sources).isSubset(of: Set(ignoredUnmarkedSources))
    }

    func ignoreUnmarkedSources() {
        ignoredUnmarkedSources = Array(Set(ignoredUnmarkedSources).union(unmarked.sources)).sorted()
    }

    private func refreshShown() {
        unmarked = HRSample.unmarkedBackground(periodSamples)
        shownSamples = HRSample.filtered(periodSamples, background: includeBackground,
                                         workouts: includeWorkouts)
        minuteSamples = workoutGaps == .wholeWorkout
            ? ActiveMinutes.extendingWorkouts(shownSamples, periodWorkouts) : shownSamples
    }
    var errorMessage: String?
    /// The last fetch from Health failed or was interrupted (the data is incomplete).
    private(set) var loadFailed = false

    /// Age is used for max heart rate (220 − age). Stored; read from Health the first time.
    var age: Int = UserDefaults.standard.object(forKey: "age") as? Int ?? Defaults.age {
        didSet { UserDefaults.standard.set(age, forKey: "age") }
    }

    /// Max heart rate from age (220 − age) or entered.
    var maxHRSource: MaxHRSource = MaxHRSource(rawValue: UserDefaults.standard.string(forKey: "maxHRSource") ?? "") ?? Defaults.maxHRSource {
        didSet { UserDefaults.standard.set(maxHRSource.rawValue, forKey: "maxHRSource") }
    }
    /// Entered max heart rate (e.g. measured in a test).
    var manualMaxHR: Int = UserDefaults.standard.object(forKey: "manualMaxHR") as? Int ?? 180 {
        didSet { UserDefaults.standard.set(manualMaxHR, forKey: "manualMaxHR") }
    }
    /// The max heart rate that is used.
    var maxHR: Double { maxHRSource == .age ? HeartZones.maxHR(age: age) : Double(manualMaxHR) }

    /// Age from Health (date of birth) if it can be read – default for "Age".
    private(set) var healthAge: Int?
    var defaultAge: Int { healthAge ?? Defaults.age }
    /// Default for the entered max heart rate: based on age.
    var defaultMaxHR: Int { Int(HeartZones.maxHR(age: age)) }

    /// Resets all settings to their defaults.
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
        if DemoData.isOn { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = String(localized: "Health data is not available on this device.")
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

    /// Number of measurements in the period that came from series (one entry in Health with many heart rate values).
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
                // Apple Watch often stores workout heart rate as a series: one entry with many values. Without
                // unpacking it you only get one value (and lose e.g. peaks).
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

    /// The individual heart rate values in a series entry.
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

    /// Fetches heart rate for the period and marks measurements that lie within a workout.
    func loadPeriod(_ interval: DateInterval) async {
        loadFailed = false
        let samples: [HRSample]
        let workoutIntervals: [DateInterval]
        let exercise: [(interval: DateInterval, end: Date, minutes: Double)]
        if DemoData.isOn {
            let demo = DemoData.period(interval)
            samples = demo.samples
            workoutIntervals = demo.workouts.map(\.interval)
            for w in demo.workouts { workoutTypes[w.interval.start] = w.type }
            exercise = demo.exercise.map { ($0, $0.end, $0.duration / 60) }
        } else {
            samples = await heartRates(from: interval.start, to: interval.end)
            workoutIntervals = await self.workoutIntervals(from: interval.start, to: interval.end)
            exercise = await exerciseSamples(from: interval.start, to: interval.end)
        }
        // Interrupted (e.g. when iOS stops a background refresh, or a new period was selected): the data is incomplete
        // or stale, so it isn't shown.
        if Task.isCancelled { loadFailed = true; return }
        loadedInterval = interval
        applePoints = ActiveMinutes.cumulativeExercise(exercise.map { (end: $0.end, minutes: $0.minutes) },
                                                       start: interval.start)
        periodWorkouts = workoutIntervals
        periodSamples = HRSample.markingExercise(HRSample.markingWorkouts(samples, workoutIntervals),
                                                 exercise.map(\.interval))
    }

    /// Exercise minutes (the green ring) in the period, added up over time.
    func exerciseMinutes(from start: Date, to end: Date) async -> [ActiveMinutes.Point] {
        ActiveMinutes.cumulativeExercise(
            await exerciseSamples(from: start, to: end).map { (end: $0.end, minutes: $0.minutes) }, start: start)
    }

    /// Exercise minutes as individual time ranges (usually one per minute).
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

    /// The time ranges of the workouts that overlap the period.
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
    /// This week's Heart Minutes for the complication and widgets, calculated with the saved settings. `nil` if Health
    /// couldn't be read (so the saved numbers aren't overwritten with 0).
    static func weekSummary(now: Date = .now) async -> ComplicationData? {
        await summary(for: .thisWeek, now: now)
    }

    /// Heart Minutes for all widget periods at once: data is fetched once for the combined time range and then split up
    /// (faster than fetching each period separately).
    static func summaries(now: Date = .now) async -> [SummaryPeriod: ComplicationData] {
        let intervals = Dictionary(uniqueKeysWithValues: SummaryPeriod.allCases.map { ($0, $0.interval(now: now)) })
        guard let start = intervals.values.map(\.start).min(),
              let end = intervals.values.map(\.end).max() else { return [:] }
        let health = HealthManager()
        await health.loadPeriod(DateInterval(start: start, end: end))
        // Error or interrupted fetch: save nothing – better old numbers than 0.
        guard !health.loadFailed else { return [:] }
        var result: [SummaryPeriod: ComplicationData] = [:]
        for (period, interval) in intervals {
            let slice = Array(health.minuteSamples.slice(from: interval.start, to: interval.end))
            let r = ActiveMinutes(slice, config: health.minutesConfig)
            let points = r.points
            let zoneSlices = health.zones.slices(r.zoneMinutes)
            result[period] = ComplicationData(
                minutes: points.last?.total ?? 0,
                goal: period.goal(weekly: Double(health.weeklyGoal), now: now),
                updated: now,
                points: ComplicationData.reduced(points.map { .init(t: $0.date, v: $0.total) }),
                zones: zoneSlices)
        }
        return result
    }

    /// Heart Minutes for one period (week, day, 7 days) for widgets.
    static func summary(for period: SummaryPeriod, now: Date = .now) async -> ComplicationData? {
        let health = HealthManager()
        await health.loadPeriod(period.interval(now: now))
        guard !health.loadFailed else { return nil }
        let points = ActiveMinutes(health.minuteSamples, config: health.minutesConfig).points
        return ComplicationData(
            minutes: points.last?.total ?? 0,
            goal: period.goal(weekly: Double(health.weeklyGoal), now: now),
            updated: now,
            points: ComplicationData.reduced(points.map { .init(t: $0.date, v: $0.total) }))
    }
}
