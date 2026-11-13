import SwiftUI
import HealthKit
import Charts

/// Chart of the cumulative active minutes in the period, with the goal as a horizontal line.
struct ActiveMinutesChart: View {
    let result: ActiveMinutes
    /// Header with the number (turned off when the big heart ring is shown above).
    var showHeader = true
    let period: ClosedRange<Date>
    /// The zones with names and factors (for the calculation below the chart).
    let zones: HeartZones
    let weeklyGoal: Double
    /// Exercise minutes, cumulative (empty without access/data).
    var applePoints: [ActiveMinutes.Point] = []
    /// Show the other source as a line for comparison.
    var showComparison: Bool = true
    /// Show the line "Moderate … × 1 + vigorous … × 2" below the chart.
    var showBreakdown: Bool = true

    static let appleColor = Color(red: 0.55, green: 0.85, blue: 0.0)

    private var appleTotal: Double { applePoints.last?.total ?? 0 }
    /// The curves are extended horizontally to now (or the end of the period), so they continue through days without
    /// minutes.
    private var curveEnd: Date { min(.now, period.upperBound) }
    private var shownPoints: [ActiveMinutes.Point] {
        ActiveMinutes.spanning(result.points, from: period.lowerBound, to: curveEnd)
    }
    private var shownApplePoints: [ActiveMinutes.Point] {
        ActiveMinutes.spanning(applePoints, from: period.lowerBound, to: curveEnd)
    }
    private var shownTotal: Double { result.total }
    private var comparedTotal: Double { showComparison ? appleTotal : 0 }
    private var yMax: Double { max(shownTotal, comparedTotal, goal, 1) * 1.15 }

    private var goal: Double {
        ActiveMinutes.scaledGoal(weekly: weeklyGoal,
                                 duration: period.upperBound.timeIntervalSince(period.lowerBound))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeader {
                HStack(alignment: .firstTextBaseline) {
                    Text("Heart Minutes").font(.headline)
                    Spacer()
                    Text("\(Int(shownTotal.rounded()))").font(.title2.bold())
                    Text("/ \(Int(goal.rounded()))").foregroundStyle(.secondary)
                    if shownTotal >= goal && goal > 0 {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
            }
            Chart {
                // Stacked: background measurements at the bottom, workouts on top – the same colours as the heart rate
                // chart.
                ForEach(shownPoints) { p in
                    AreaMark(x: .value("Time", p.date), y: .value("Minutes", p.background),
                             stacking: .standard)
                        .foregroundStyle(by: .value("Source", "Background"))
                    AreaMark(x: .value("Time", p.date), y: .value("Minutes", p.workout),
                             stacking: .standard)
                        .foregroundStyle(by: .value("Source", "Workout"))
                }
                if showComparison {
                    ForEach(shownApplePoints) { p in
                        LineMark(x: .value("Time", p.date), y: .value("Apple", p.total),
                                 series: .value("Series", "Apple"))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(Self.appleColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
                RuleMark(y: .value("Goal", goal))
                    // Grey dashed goal line – the same as in the widgets.
                    .foregroundStyle(Color.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Goal \(Int(goal.rounded())) min").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: period)
            .chartYScale(domain: 0...yMax)
            .chartForegroundStyleScale([
                "Background": Brand.area(HeartChart.backgroundColor, top: 0.5),
                "Workout": Brand.area(HeartChart.workoutColor, top: 0.55),
            ])
            // Calm y axis: few, faint lines.
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.18))
                    AxisValueLabel()
                }
            }
            .chartLegend(.hidden)
            .frame(height: 160)

            // Full font size: on one line if there is room – otherwise one per line.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { heartRateLegends }
                VStack(alignment: .leading, spacing: 4) { heartRateLegends }
            }
            .font(.caption)

            if showBreakdown {
            // With one decimal so the sum adds up (rounded whole minutes can be 1 short).
            ZoneBreakdown(result: result, zones: zones)
            }
            Text("Goal: \(Int(weeklyGoal)) min per week, adjusted to the selected period")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// "Moderate 12.3 min × 1 + vigorous 4.0 min × 2 = 20 min" – zones that count (× 0 is left out; with 5 zones also
    /// zones without minutes).
    static func breakdown(_ result: ActiveMinutes, zones: HeartZones) -> String {
        let one = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        let weight = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        var terms: [String] = []
        for i in zones.indices {
            let minutes = i < result.zoneMinutes.count ? result.zoneMinutes[i] : 0
            guard zones.weights[i] > 0, minutes > 0 || zones.model == .two else { continue }
            // Two zones: "Moderate … + vigorous …" (only the first capitalised).
            let name = zones.model == .two && !terms.isEmpty ? zones.name(i).lowercased() : zones.name(i)
            terms.append(String(localized: "\(name) \(minutes.formatted(one)) min × \(zones.weights[i].formatted(weight))"))
        }
        let sum = terms.isEmpty ? "0 min" : terms.joined(separator: " + ")
        return "\(sum) = \(Int(result.total.rounded())) min"
    }

    @ViewBuilder private var heartRateLegends: some View {
        legend(HeartChart.backgroundColor, "Background activity: \(Int(result.backgroundTotal.rounded())) min")
        legend(HeartChart.workoutColor, "Workouts: \(Int(result.workoutTotal.rounded())) min")
        if showComparison {
            line(Self.appleColor, "Exercise ring: \(Int(appleTotal.rounded())) min")
        }
    }

    private func dashed(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Path { p in p.move(to: .init(x: 0, y: 5)); p.addLine(to: .init(x: 14, y: 5)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
                .frame(width: 14, height: 10)
            Text(title)
        }
    }

    /// Solid line (Exercise minutes as a line on top of the chart).
    private func line(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 14, height: 2.5)
            Text(title)
        }
    }

    private func legend(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.6)).frame(width: 10, height: 10)
            Text(title)
        }
    }
}

/// The period's workouts with points. Tap a workout to zoom the heart rate chart to it.
struct WorkoutScoresView: View {
    let scores: [ActiveMinutes.WorkoutScore]
    let zones: HeartZones
    /// SF Symbol for the workout's type (e.g. running, cycling, strength), by start time.
    var icon: (Date) -> String = { _ in "figure.mixed.cardio" }
    var onSelect: (DateInterval) -> Void = { _ in }

    /// Minutes in the zones that count (e.g. "moderate 3.2", "Z4 1.0").
    private func zoneParts(_ r: ActiveMinutes) -> [String] {
        zones.indices.compactMap { i in
            let m = i < r.zoneMinutes.count ? r.zoneMinutes[i] : 0
            guard zones.weights[i] > 0, m > 0 || zones.model == .two else { return nil }
            let name = zones.model == .two ? zones.name(i).lowercased() : zones.name(i)
            return "\(name) \(m.formatted(.number.precision(.fractionLength(1))))"
        }
    }

    // Group (not VStack): in a List the header and each workout become their own row. One tall row with all workouts
    // got the wrong height and was drawn over the row above.
    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workouts").font(.headline)
                if !scores.isEmpty {
                    Text("Tap a workout to see it in the heart rate chart.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(scores) { w in
                Button { onSelect(w.interval) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                // Workout colour and icon, so it's clear the row can be tapped.
                                Label {
                                    Text(w.interval.start, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                                } icon: {
                                    Image(systemName: icon(w.interval.start))
                                }
                                .foregroundStyle(HeartChart.workoutColor)
                                Spacer()
                                Text("\(w.result.total, format: .number.precision(.fractionLength(1))) min").bold()
                            }
                            Text(([ "\(Int((w.interval.duration / 60).rounded())) min" ] + zoneParts(w.result)
                                  + [String(localized: "\(w.sampleCount) measurements")]).joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(HeartChart.workoutColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Zoom the heart rate chart to this workout")
                .listRowSeparator(.hidden)
                // A little more space below the last card so it doesn't touch the edge.
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: w.id == scores.last?.id ? 16 : 4, trailing: 16))
            }
            if scores.isEmpty {
                Text("No workouts in this period").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}



extension HKWorkoutActivityType {
    /// SF Symbol matching the workout type from Health.
    var symbolName: String {
        switch self {
        case .running: "figure.run"
        case .walking: "figure.walk"
        case .hiking: "figure.hiking"
        case .cycling: "figure.outdoor.cycle"
        case .swimming: "figure.pool.swim"
        case .rowing: "figure.rower"
        case .elliptical: "figure.elliptical"
        case .stairClimbing, .stairs: "figure.stair.stepper"
        case .traditionalStrengthTraining: "figure.strengthtraining.traditional"
        case .functionalStrengthTraining: "figure.strengthtraining.functional"
        case .coreTraining: "figure.core.training"
        case .highIntensityIntervalTraining: "figure.highintensity.intervaltraining"
        case .crossTraining: "figure.cross.training"
        case .mixedCardio: "figure.mixed.cardio"
        case .yoga: "figure.yoga"
        case .pilates: "figure.pilates"
        case .flexibility: "figure.flexibility"
        case .cooldown: "figure.cooldown"
        case .dance, .socialDance, .cardioDance: "figure.dance"
        case .soccer: "figure.soccer"
        case .basketball: "figure.basketball"
        case .tennis: "figure.tennis"
        case .badminton: "figure.badminton"
        case .tableTennis: "figure.table.tennis"
        case .golf: "figure.golf"
        case .downhillSkiing: "figure.skiing.downhill"
        case .crossCountrySkiing: "figure.skiing.crosscountry"
        case .snowboarding: "figure.snowboarding"
        case .climbing: "figure.climbing"
        case .boxing, .kickboxing: "figure.boxing"
        case .martialArts: "figure.martial.arts"
        case .handball: "figure.handball"
        case .volleyball: "figure.volleyball"
        case .handCycling: "figure.hand.cycling"
        case .paddleSports: "oar.2.crossed"
        case .surfingSports: "figure.surfing"
        case .skatingSports: "figure.skating"
        case .jumpRope: "figure.jumprope"
        case .mindAndBody: "figure.mind.and.body"
        default: "figure.mixed.cardio"
        }
    }
}

/// The zone bar below the minutes chart. Tap to see the calculation ("Z1 … × 1 + Z3 … × 2 = N min").
struct ZoneBreakdown: View {
    let result: ActiveMinutes
    let zones: HeartZones
    @State private var showMath = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZoneBar(slices: zones.slices(result.zoneMinutes))
            if showMath {
                Text(ActiveMinutesChart.breakdown(result, zones: zones))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation { showMath.toggle() } }
        .accessibilityHint("Tap to see the calculation")
    }
}

/// The big heart ring at the top of Overview: the period's Heart Minutes against the goal.
struct HeroRing: View {
    let total: Double
    let goal: Double
    /// New period: the ring counts up from 0 again.
    var period: DateInterval? = nil
    @Environment(\.colorScheme) private var colorScheme

    private var fraction: Double { goal > 0 ? max(0, total / goal) : 0 }
    private var reached: Bool { goal > 0 && total >= goal }

    var body: some View {
        VStack(spacing: 6) {
            CountingHeartRing(total: total, goal: goal,
                              resetKey: period.map { "\($0.start.timeIntervalSince1970)-\($0.end.timeIntervalSince1970)" } ?? "")
                .frame(width: 170, height: 170)
                // Dark mode: the ring glows a little, like on the watch.
                .shadow(color: colorScheme == .dark ? Brand.accent.opacity(0.4) : .clear, radius: 14)
            HStack(spacing: 6) {
                Text("of \(Int(goal.rounded())) min · \(Int((fraction * 100).rounded())) %")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if reached {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
