import Foundation

/// Periods widgets can show.
enum SummaryPeriod: String, CaseIterable, Codable, Sendable {
    case today, thisWeek, thisMonth, last3Days, last7Days, last14Days, last30Days

    var title: String {
        switch self {
        case .today: String(localized: "Today")
        case .last3Days: String(localized: "Last 3 days")
        case .thisWeek: String(localized: "This week")
        case .last7Days: String(localized: "Last 7 days")
        case .last14Days: String(localized: "Last 14 days")
        case .thisMonth: String(localized: "This month")
        case .last30Days: String(localized: "Last 30 days")
        }
    }

    /// Number of days for the rolling periods ("last N days").
    var rollingDays: Int? {
        switch self {
        case .last3Days: 3
        case .last7Days: 7
        case .last14Days: 14
        case .last30Days: 30
        default: nil
        }
    }

    /// The time range that is calculated.
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

    /// The chart's whole time axis (e.g. the whole week Monday–Sunday, even if the week isn't over).
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

    /// The length in days the goal is scaled by.
    func goalDays(now: Date = .now, calendar: Calendar = .current) -> Double {
        if let days = rollingDays { return Double(days) }
        switch self {
        case .today: return 1
        case .thisMonth: return Double(calendar.range(of: .day, in: .month, for: now)?.count ?? 30)
        default: return 7
        }
    }

    /// The goal for the period from the weekly goal (one day = 1/7 of the weekly goal).
    func goal(weekly: Double, now: Date = .now) -> Double { weekly * goalDays(now: now) / 7 }

    var goalLabel: String {
        switch self {
        case .today: String(localized: "today’s goal")
        case .thisWeek: String(localized: "this week’s goal")
        case .thisMonth: String(localized: "this month’s goal")
        default: String(localized: "the goal for \(rollingDays ?? 7) days")
        }
    }

    /// The week uses the original key, so the watch complication and older data still work.
    var storageKey: String { self == .thisWeek ? "complicationData" : "complicationData.\(rawValue)" }
}

/// Minutes in one heart rate zone with the zone's colour (for the zone bar in the app and widgets).
struct ZoneSlice: Codable, Equatable, Sendable {
    var name: String
    var minutes: Double
    var r: Double
    var g: Double
    var b: Double
}

/// This week's Heart Minutes, shared between the watch app and the complication (App Group).
struct ComplicationData: Codable, Equatable {
    var minutes: Double
    var goal: Double
    var updated: Date
    /// Cumulative curve over the week (for the chart in the Home Screen widget). Missing in older data.
    var points: [Point]? = nil
    /// The split across heart rate zones (only zones that count). Missing in older data.
    var zones: [ZoneSlice]? = nil

    struct Point: Codable, Equatable {
        let t: Date
        let v: Double
    }

    /// At most `max` points (evenly spread, the last point kept) – widgets have little memory.
    static func reduced(_ points: [Point], max: Int = 120) -> [Point] {
        guard points.count > max, max > 1 else { return points }
        let step = Double(points.count - 1) / Double(max - 1)
        return (0..<max).map { points[Int((Double($0) * step).rounded())] }
    }

    /// Extends the curve horizontally to `end` so it continues through days without new minutes.
    static func extended(_ points: [Point], to end: Date) -> [Point] {
        guard let last = points.last, end > last.t else { return points }
        return points + [Point(t: end, v: last.v)]
    }

    /// The whole curve for the chart: starts at 0 at the start of the period (if the first minute comes later) and
    /// continues horizontally to `end`.
    static func spanning(_ points: [Point], from start: Date, to end: Date) -> [Point] {
        var p = points
        if let first = p.first, first.t > start { p.insert(Point(t: start, v: 0), at: 0) }
        else if p.isEmpty { p = [Point(t: start, v: 0)] }
        return extended(p, to: end)
    }

    var fraction: Double { goal > 0 ? max(0, minutes / goal) : 0 }
    var percent: Int { Int((fraction * 100).rounded()) }

    static let placeholder = ComplicationData(minutes: 93, goal: 150, updated: .now)

    /// Data from an earlier week/day is shown as 0 (new period = start over).
    func current(for period: SummaryPeriod = .thisWeek, now: Date = .now) -> ComplicationData {
        // Rolling periods aren't reset; week, day and month start over.
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

    /// Only saves if `shouldReplace` says yes. Returns whether it saved.
    @discardableResult
    static func saveIfValid(_ data: ComplicationData, for period: SummaryPeriod = .thisWeek,
                            allowDecrease: Bool) -> Bool {
        guard shouldReplace(load(for: period), with: data, for: period, allowDecrease: allowDecrease)
        else { return false }
        save(data, for: period)
        return true
    }

    /// Within the same day/week/month the minutes can only go up. A lower number in the background is therefore an
    /// incomplete read of Health and must not overwrite the saved number. With the app open (`allowDecrease`) the
    /// number may drop, e.g. after changed settings. Rolling periods ("last N days") can drop naturally and aren't
    /// checked.
    static func shouldReplace(_ old: ComplicationData?, with new: ComplicationData, for period: SummaryPeriod,
                              allowDecrease: Bool, now: Date = .now) -> Bool {
        guard !allowDecrease, let old, period.rollingDays == nil,
              old.updated >= period.interval(now: now).start else { return true }
        return new.minutes >= old.minutes
    }

    /// The period the watch (complications and watch app) shows. Chosen in the iPhone app and synced; stored in the App
    /// Group so the complication can read it too.
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
