import Foundation
import HealthKit

/// Sample data for App Store screenshots and the Simulator, which has no heart rate data. Only used when the app is
/// launched with `-DemoData YES`; Health is then neither asked nor read.
///
/// A typical week (with the default settings: age 40, moderate from 90 bpm, vigorous from 126 bpm): resting heart rate
/// during the day, a brisk walk at lunch every weekday (background measurements, no workout), a run on Monday and a long
/// hike on Saturday – about 210 Heart Minutes for the whole week, almost half of them from everyday activity. The same
/// day always gives the same values.
enum DemoData {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "DemoData") }

    struct Workout {
        let interval: DateInterval
        let type: HKWorkoutActivityType
    }

    struct Content {
        var samples: [HRSample] = []
        var workouts: [Workout] = []
        /// Minutes that count in the Exercise ring.
        var exercise: [DateInterval] = []
    }

    /// The data for `interval`, up to `now` (nothing in the future).
    static func period(_ interval: DateInterval, now: Date = .now, calendar: Calendar = .current) -> Content {
        var result = Content()
        let end = min(interval.end, now)
        guard end > interval.start else { return result }
        var day = calendar.startOfDay(for: interval.start)
        while day < end {
            add(day: day, to: &result, calendar: calendar)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        let range = interval.start...end
        result.samples = result.samples.filter { range.contains($0.date) }.sorted { $0.date < $1.date }
        result.workouts = result.workouts.compactMap { w in
            guard w.interval.start < end, w.interval.end > interval.start else { return nil }
            return Workout(interval: DateInterval(start: w.interval.start, end: min(w.interval.end, end)), type: w.type)
        }
        result.exercise = result.exercise.filter { $0.start >= interval.start && $0.end <= end }
        return result
    }

    private static func add(day: Date, to result: inout Content, calendar: Calendar) {
        var random = SeededRandom(seed: UInt64(max(0, Int(day.timeIntervalSinceReferenceDate / 86_400))))
        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        // The day's activity first. 1 = Sunday … 7 = Saturday.
        var activity = Content()
        switch calendar.component(.weekday, from: day) {
        case 2...6:
            // Weekdays: a brisk walk at lunch – counted from the watch's background measurements, not a workout.
            walk(at(12, 10 + Int(random.next(in: 0...15))), minutes: 18, &random, &activity)
            if calendar.component(.weekday, from: day) == 2 {
                workout(.running, at(18, 5), minutes: 32, level: 140, warmUp: 6, &random, &activity)
            }
        case 7: workout(.hiking, at(10, 20), minutes: 64, level: 106, warmUp: 4, &random, &activity)
        default: break
        }
        // Resting heart rate every 6 minutes from 7:00 to 22:30, but not during (or right around) the activity.
        var busy: [DateInterval] = []   // one per walk/workout (a new one after a gap of more than 10 minutes)
        for sample in activity.samples {
            if let last = busy.last, sample.date.timeIntervalSince(last.end) <= 600 {
                busy[busy.count - 1].end = sample.date
            } else {
                busy.append(DateInterval(start: sample.date, end: sample.date))
            }
        }
        var t = at(7, 0)
        while t < at(22, 30) {
            if !busy.contains(where: { t >= $0.start - 240 && t <= $0.end + 240 }) {
                result.samples.append(HRSample(date: t, bpm: 64 + random.next(in: 0...12), motion: .sedentary,
                                               source: "Apple Watch"))
            }
            t += 360
        }
        result.samples += activity.samples
        result.workouts += activity.workouts
        result.exercise += activity.exercise
    }

    /// A brisk walk outside a workout: one measurement a minute, marked active by the watch.
    private static func walk(_ start: Date, minutes: Int, _ random: inout SeededRandom, _ result: inout Content) {
        for m in 0...minutes {
            let date = start + Double(m) * 60
            result.samples.append(HRSample(date: date, bpm: 104 + random.next(in: 0...10), motion: .active,
                                           source: "Apple Watch"))
            if m < minutes { result.exercise.append(DateInterval(start: date, duration: 60)) }
        }
    }

    /// A workout with a measurement every 10 seconds: warm-up, a steady part that varies a little, and a cool-down.
    private static func workout(_ type: HKWorkoutActivityType, _ start: Date, minutes: Int, level: Double,
                                warmUp: Double, _ random: inout SeededRandom, _ result: inout Content) {
        let duration = Double(minutes) * 60
        result.workouts.append(Workout(interval: DateInterval(start: start, duration: duration), type: type))
        var t = 0.0
        while t <= duration {
            let minute = t / 60
            let ramp = min(minute / warmUp, 1) * min((Double(minutes) - minute) / 3, 1)
            let bpm = 92 + (level - 92) * ramp + 5 * sin(minute / 2.5) + random.next(in: -2...2)
            result.samples.append(HRSample(date: start + t, bpm: bpm, motion: .active, source: "Apple Watch"))
            t += 10
        }
        for m in 0..<minutes {
            result.exercise.append(DateInterval(start: start + Double(m) * 60, duration: 60))
        }
    }
}

/// A small random number generator that gives the same numbers for the same seed (SplitMix64).
private struct SeededRandom {
    var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func nextUInt() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * Double(nextUInt() >> 11) / Double(1 << 53)
    }
}
