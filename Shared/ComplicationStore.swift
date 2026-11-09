import Foundation

/// Perioder, widgets kan vise.
enum SummaryPeriod: String, CaseIterable, Codable, Sendable {
    case today, thisWeek, thisMonth, last3Days, last7Days, last14Days, last30Days

    var title: String {
        switch self {
        case .today: "I dag"
        case .last3Days: "Seneste 3 dage"
        case .thisWeek: "Denne uge"
        case .last7Days: "Seneste 7 dage"
        case .last14Days: "Seneste 14 dage"
        case .thisMonth: "Denne måned"
        case .last30Days: "Seneste 30 dage"
        }
    }

    /// Antal dage for de glidende perioder ("seneste N dage").
    var rollingDays: Int? {
        switch self {
        case .last3Days: 3
        case .last7Days: 7
        case .last14Days: 14
        case .last30Days: 30
        default: nil
        }
    }

    /// Tidsrummet, der regnes på.
    func interval(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        if let days = rollingDays {
            return DateInterval(start: now.addingTimeInterval(-Double(days) * 86_400), end: now)
        }
        switch self {
        case .today: return Period.day(containing: now)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return DateInterval(start: start, end: max(start, Period.day(containing: now).end))
        default: return Period.thisWeek(now: now)
        }
    }

    /// Hele grafens tidsakse (fx hele ugen mandag–søndag, selvom ugen ikke er slut).
    func chartDomain(now: Date = .now, calendar: Calendar = .current) -> ClosedRange<Date> {
        let i = interval(now: now, calendar: calendar)
        switch self {
        case .thisWeek:
            return i.start...(calendar.date(byAdding: .day, value: 7, to: i.start) ?? i.end)
        case .thisMonth:
            let month = calendar.dateInterval(of: .month, for: now)
            return i.start...(month?.end ?? i.end)
        default:
            return i.start...i.end
        }
    }

    /// Længden i dage, som målet skaleres efter.
    func goalDays(now: Date = .now, calendar: Calendar = .current) -> Double {
        if let days = rollingDays { return Double(days) }
        switch self {
        case .today: return 1
        case .thisMonth: return Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        default: return 7
        }
    }

    /// Målet for perioden ud fra ugemålet (én dag = 1/7 af ugemålet).
    func goal(weekly: Double, now: Date = .now) -> Double { weekly * goalDays(now: now) / 7 }

    var goalLabel: String {
        switch self {
        case .today: "dagens mål"
        case .thisWeek: "ugens mål"
        case .thisMonth: "månedens mål"
        default: "målet for \(rollingDays ?? 7) dage"
        }
    }

    /// Ugen bruger den oprindelige nøgle, så ur-komplikationen og ældre data stadig virker.
    var storageKey: String { self == .thisWeek ? "complicationData" : "complicationData.\(rawValue)" }
}

/// Ugens Heart Minutes, delt mellem ur-appen og komplikationen (App Group).
struct ComplicationData: Codable, Equatable {
    var minutes: Double
    var goal: Double
    var updated: Date
    /// Kumulativ kurve over ugen (til grafen i hjemmeskærm-widgetten). Mangler i ældre data.
    var points: [Point]? = nil

    struct Point: Codable, Equatable {
        let t: Date
        let v: Double
    }

    /// Højst `max` punkter (jævnt fordelt, sidste punkt beholdes) – widgets har lidt hukommelse.
    static func reduced(_ points: [Point], max: Int = 120) -> [Point] {
        guard points.count > max, max > 1 else { return points }
        let step = Double(points.count - 1) / Double(max - 1)
        return (0..<max).map { points[Int((Double($0) * step).rounded())] }
    }

    /// Forlænger kurven vandret til `end`, så den fortsætter gennem dage uden nye minutter.
    static func extended(_ points: [Point], to end: Date) -> [Point] {
        guard let last = points.last, end > last.t else { return points }
        return points + [Point(t: end, v: last.v)]
    }

    /// Hele kurven til grafen: starter i 0 ved periodens start (hvis første minut kommer senere)
    /// og fortsætter vandret til `end`.
    static func spanning(_ points: [Point], from start: Date, to end: Date) -> [Point] {
        var p = points
        if let first = p.first, first.t > start { p.insert(Point(t: start, v: 0), at: 0) }
        else if p.isEmpty { p = [Point(t: start, v: 0)] }
        return extended(p, to: end)
    }

    var fraction: Double { goal > 0 ? max(0, minutes / goal) : 0 }
    var percent: Int { Int((fraction * 100).rounded()) }

    static let placeholder = ComplicationData(minutes: 93, goal: 150, updated: .now)

    /// Data fra en tidligere uge/dag vises som 0 (ny periode = start forfra).
    func current(for period: SummaryPeriod = .thisWeek, now: Date = .now) -> ComplicationData {
        // Glidende perioder nulstilles ikke; uge, dag og måned starter forfra.
        if period.rollingDays != nil || updated >= period.interval(now: now).start { return self }
        return ComplicationData(minutes: 0, goal: goal, updated: now, points: [])
    }
}

enum ComplicationStore {
    static let appGroup = "group.dk.erik.puls"

    static func save(_ data: ComplicationData, for period: SummaryPeriod = .thisWeek) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: period.storageKey)
    }

    /// Gemmer kun, hvis `shouldReplace` siger ja. Returnerer, om der blev gemt.
    @discardableResult
    static func saveIfValid(_ data: ComplicationData, for period: SummaryPeriod = .thisWeek,
                            allowDecrease: Bool) -> Bool {
        guard shouldReplace(load(for: period), with: data, for: period, allowDecrease: allowDecrease)
        else { return false }
        save(data, for: period)
        return true
    }

    /// Inden for samme dag/uge/måned kan minutterne kun stige. Et lavere tal i baggrunden er
    /// derfor en ufuldstændig læsning af Sundhed og må ikke overskrive det gemte tal.
    /// Med appen åben (`allowDecrease`) må tallet godt falde, fx efter ændrede indstillinger.
    /// Glidende perioder ("seneste N dage") kan falde naturligt og tjekkes ikke.
    static func shouldReplace(_ old: ComplicationData?, with new: ComplicationData, for period: SummaryPeriod,
                              allowDecrease: Bool, now: Date = .now) -> Bool {
        guard !allowDecrease, let old, period.rollingDays == nil,
              old.updated >= period.interval(now: now).start else { return true }
        return new.minutes >= old.minutes
    }

    /// Perioden, som uret (komplikationer og ur-app) viser. Vælges i iPhone-appen og synkroniseres;
    /// ligger i App Group, så komplikationen også kan læse den.
    static var watchPeriod: SummaryPeriod {
        get {
            UserDefaults(suiteName: appGroup)?.string(forKey: "watchPeriod")
                .flatMap(SummaryPeriod.init(rawValue:)) ?? .thisWeek
        }
        set { UserDefaults(suiteName: appGroup)?.set(newValue.rawValue, forKey: "watchPeriod") }
    }

    static func load(for period: SummaryPeriod = .thisWeek) -> ComplicationData? {
        guard let raw = UserDefaults(suiteName: appGroup)?.data(forKey: period.storageKey) else { return nil }
        return try? JSONDecoder().decode(ComplicationData.self, from: raw)
    }
}
