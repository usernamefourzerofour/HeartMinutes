import Foundation

/// Helpers for a freely chosen period (DateInterval).
enum Period {
    /// Default: the whole day containing `date` (00:00–24:00).
    static func day(containing date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    /// ISO weeks: Monday is the first day, week numbers as in Denmark.
    static func weekCalendar(_ calendar: Calendar) -> Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = calendar.timeZone
        c.locale = calendar.locale
        return c
    }

    /// The whole week (Monday 00:00 – next Monday 00:00) containing `date`.
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let wc = weekCalendar(calendar)
        return wc.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
    }

    /// Default view: the whole current week (Monday–Sunday), including the days still to come, so the goal is the whole
    /// week's goal.
    static func thisWeek(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        week(containing: now, calendar: calendar)
    }

    /// Does the period start on a Monday and lie within the same week (and span more than one day)? Then it's treated
    /// as a week – even if it only runs until today.
    static func isWeekLike(_ interval: DateInterval, calendar: Calendar = .current) -> Bool {
        guard let days = wholeDays(interval, calendar: calendar), days >= 2 else { return false }
        let w = week(containing: interval.start, calendar: calendar)
        return w.start == interval.start && interval.end <= w.end
    }

    /// Number of whole days if the period runs from midnight to midnight; otherwise nil.
    static func wholeDays(_ interval: DateInterval, calendar: Calendar = .current) -> Int? {
        guard calendar.startOfDay(for: interval.start) == interval.start,
              calendar.startOfDay(for: interval.end) == interval.end,
              let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day,
              days > 0 else { return nil }
        return days
    }

    /// Jump `count` periods of the same length forward (positive) or back (negative). Whole days move in calendar days,
    /// so daylight saving time doesn't shift the period.
    static func shifted(_ interval: DateInterval, by count: Int,
                        calendar: Calendar = .current, now: Date = .now) -> DateInterval {
        // Weeks jump whole weeks (Monday–Sunday, also the current one).
        if isWeekLike(interval, calendar: calendar),
           let start = calendar.date(byAdding: .day, value: 7 * count, to: interval.start),
           let end = calendar.date(byAdding: .day, value: 7, to: start) {
            return DateInterval(start: start, end: end)
        }
        if let days = wholeDays(interval, calendar: calendar),
           let start = calendar.date(byAdding: .day, value: days * count, to: interval.start),
           let end = calendar.date(byAdding: .day, value: days, to: start) {
            return DateInterval(start: start, end: end)
        }
        return DateInterval(start: interval.start.addingTimeInterval(interval.duration * Double(count)),
                            duration: interval.duration)
    }

    /// When the app comes back: a period that followed "now" (this week, today, this month or a rolling window that
    /// ended at the last load) moves along to the new "now". Other periods (e.g. an older week) stay as they are.
    static func refreshed(_ interval: DateInterval, from then: Date, to now: Date = .now,
                          calendar: Calendar = .current) -> DateInterval {
        if interval == thisWeek(now: then, calendar: calendar) { return thisWeek(now: now, calendar: calendar) }
        if interval == day(containing: then, calendar: calendar) { return day(containing: now, calendar: calendar) }
        if let month = calendar.dateInterval(of: .month, for: then), month == interval {
            return calendar.dateInterval(of: .month, for: now) ?? interval
        }
        if abs(interval.end.timeIntervalSince(then)) < 5 * 60 {
            return DateInterval(start: interval.start.addingTimeInterval(now.timeIntervalSince(then)),
                                duration: interval.duration)
        }
        return interval
    }

    static func label(_ interval: DateInterval, calendar: Calendar = .current, now: Date = .now) -> String {
        // A rolling window ending now: a short name instead of two timestamps.
        if abs(interval.end.timeIntervalSince(now)) < 5 * 60 {
            let end = interval.end
            func near(_ date: Date?) -> Bool { date.map { abs($0.timeIntervalSince(interval.start)) < 5 * 60 } ?? false }
            if near(calendar.date(byAdding: .year, value: -1, to: end)) { return String(localized: "Last year") }
            if near(calendar.date(byAdding: .month, value: -1, to: end)) { return String(localized: "Last month") }
            let days = interval.duration / 86_400
            if abs(days - days.rounded()) < 0.01, days.rounded() >= 1 {
                let n = Int(days.rounded())
                return n == 1 ? String(localized: "Last 24 hours") : String(localized: "Last \(n) days")
            }
        }
        // The whole calendar month.
        if let month = calendar.dateInterval(of: .month, for: interval.start), month == interval {
            return interval.start.formatted(.dateTime.month(.wide).year())
        }
        if wholeDays(interval, calendar: calendar) == 1 {
            return interval.start.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        if isWeekLike(interval, calendar: calendar) {
            let week = weekCalendar(calendar).component(.weekOfYear, from: interval.start)
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let fmt = Date.FormatStyle.dateTime.day().month(.abbreviated)
            return String(localized: "Week \(week) · \(interval.start.formatted(fmt)) – \(last.formatted(fmt))")
        }
        if let days = wholeDays(interval, calendar: calendar) {
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let fmt = Date.FormatStyle.dateTime.day().month(.abbreviated)
            return "\(interval.start.formatted(fmt)) – \(last.formatted(fmt)) (" + String(localized: "\(days) days") + ")"
        }
        // Short format (e.g. 2.11 21.23 – 9.11 21.23) so it fits on one line.
        let fmt = Date.FormatStyle.dateTime.day().month(.defaultDigits).hour().minute()
        return "\(interval.start.formatted(fmt)) – \(interval.end.formatted(fmt))"
    }
}
