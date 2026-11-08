import Foundation

/// Hjælpefunktioner til en frit valgt periode (DateInterval).
enum Period {
    /// Standard: hele dagen, der indeholder `date` (00:00–24:00).
    static func day(containing date: Date = .now, calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
    }

    /// ISO-uger: mandag er første dag, ugenumre som i Danmark.
    static func weekCalendar(_ calendar: Calendar) -> Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = calendar.timeZone
        c.locale = calendar.locale
        return c
    }

    /// Hele ugen (mandag 00:00 – næste mandag 00:00), der indeholder `date`.
    static func week(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let wc = weekCalendar(calendar)
        return wc.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
    }

    /// Standardvisning: hele denne uge (mandag–søndag), også de dage der ikke er kommet endnu,
    /// så målet er hele ugens mål.
    static func thisWeek(now: Date = .now, calendar: Calendar = .current) -> DateInterval {
        week(containing: now, calendar: calendar)
    }

    /// Starter perioden en mandag og ligger inden for samme uge (og er mere end én dag)?
    /// Så behandles den som en uge – også hvis den kun går til i dag.
    static func isWeekLike(_ interval: DateInterval, calendar: Calendar = .current) -> Bool {
        guard let days = wholeDays(interval, calendar: calendar), days >= 2 else { return false }
        let w = week(containing: interval.start, calendar: calendar)
        return w.start == interval.start && interval.end <= w.end
    }

    /// Antal hele dage, hvis perioden går fra midnat til midnat; ellers nil.
    static func wholeDays(_ interval: DateInterval, calendar: Calendar = .current) -> Int? {
        guard calendar.startOfDay(for: interval.start) == interval.start,
              calendar.startOfDay(for: interval.end) == interval.end,
              let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day,
              days > 0 else { return nil }
        return days
    }

    /// Hop `count` perioder af samme længde frem (positiv) eller tilbage (negativ).
    /// Hele dage flyttes i kalenderdage, så sommertid ikke skubber perioden.
    static func shifted(_ interval: DateInterval, by count: Int,
                        calendar: Calendar = .current, now: Date = .now) -> DateInterval {
        // Uger hopper hele uger (mandag–søndag, også den indeværende).
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

    static func label(_ interval: DateInterval, calendar: Calendar = .current) -> String {
        if wholeDays(interval, calendar: calendar) == 1 {
            return interval.start.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
        if isWeekLike(interval, calendar: calendar) {
            let week = weekCalendar(calendar).component(.weekOfYear, from: interval.start)
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let fmt = Date.FormatStyle.dateTime.day().month(.abbreviated)
            return "Uge \(week) · \(interval.start.formatted(fmt)) – \(last.formatted(fmt))"
        }
        if let days = wholeDays(interval, calendar: calendar) {
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
            let fmt = Date.FormatStyle.dateTime.day().month(.abbreviated)
            return "\(interval.start.formatted(fmt)) – \(last.formatted(fmt)) (\(days) dage)"
        }
        let fmt = Date.FormatStyle.dateTime.day().month(.abbreviated).hour().minute()
        return "\(interval.start.formatted(fmt)) – \(interval.end.formatted(fmt))"
    }
}
