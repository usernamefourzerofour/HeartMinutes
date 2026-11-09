import SwiftUI
import Charts

/// Graf over de kumulative aktive minutter i perioden, med målet som vandret linje.
struct ActiveMinutesChart: View {
    let result: ActiveMinutes
    let period: ClosedRange<Date>
    let moderateWeight: Double
    let vigorousWeight: Double
    let weeklyGoal: Double
    /// træningsringsminutter, kumulativt (tom hvis ingen adgang/data).
    var applePoints: [ActiveMinutes.Point] = []
    var source: ActiveMinutes.Source = .heartRate
    /// Vis den anden kilde som stiplet linje til sammenligning.
    var showComparison: Bool = true
    /// Vis linjen "Moderat … × 1 + hård … × 2" under grafen.
    var showBreakdown: Bool = true

    static let appleColor = Color(red: 0.55, green: 0.85, blue: 0.0)

    private var appleTotal: Double { applePoints.last?.total ?? 0 }
    /// Kurverne forlænges vandret til nu (eller periodens slut), så de fortsætter gennem dage uden minutter.
    private var curveEnd: Date { min(.now, period.upperBound) }
    private var shownPoints: [ActiveMinutes.Point] {
        ActiveMinutes.spanning(result.points, from: period.lowerBound, to: curveEnd)
    }
    private var shownApplePoints: [ActiveMinutes.Point] {
        ActiveMinutes.spanning(applePoints, from: period.lowerBound, to: curveEnd)
    }
    private var shownTotal: Double { source == .appleExercise ? appleTotal : result.total }
    private var comparedTotal: Double {
        guard showComparison else { return 0 }
        return source == .appleExercise ? result.total : appleTotal
    }
    private var yMax: Double { max(shownTotal, comparedTotal, goal, 1) * 1.15 }

    private var goal: Double {
        ActiveMinutes.scaledGoal(weekly: weeklyGoal,
                                 duration: period.upperBound.timeIntervalSince(period.lowerBound))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Heart Minutes").font(.headline)
                Spacer()
                Text("\(Int(shownTotal.rounded()))").font(.title2.bold())
                Text("/ \(Int(goal.rounded()))").foregroundStyle(.secondary)
                if shownTotal >= goal && goal > 0 {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(ZoneKind.moderate.color)
                }
            }
            Chart {
                if source == .heartRate {
                    // Stablet: baggrundsmålinger nederst, workouts ovenpå – samme farver som pulsgrafen.
                    ForEach(shownPoints) { p in
                        AreaMark(x: .value("Tid", p.date), y: .value("Minutter", p.background),
                                 stacking: .standard)
                            .foregroundStyle(by: .value("Kilde", "Baggrund"))
                        AreaMark(x: .value("Tid", p.date), y: .value("Minutter", p.workout),
                                 stacking: .standard)
                            .foregroundStyle(by: .value("Kilde", "Workout"))
                    }
                    if showComparison {
                        ForEach(shownApplePoints) { p in
                            LineMark(x: .value("Tid", p.date), y: .value("Apple", p.total),
                                     series: .value("Serie", "Apple"))
                                .interpolationMethod(.stepEnd)
                                .foregroundStyle(Self.appleColor)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                } else {
                    ForEach(shownApplePoints) { p in
                        AreaMark(x: .value("Tid", p.date), y: .value("Minutter", p.total))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(Self.appleColor.opacity(0.3))
                        LineMark(x: .value("Tid", p.date), y: .value("Apple", p.total),
                                 series: .value("Serie", "Apple"))
                            .interpolationMethod(.stepEnd)
                            .foregroundStyle(Self.appleColor)
                    }
                    if showComparison {
                        ForEach(shownPoints) { p in
                            LineMark(x: .value("Tid", p.date), y: .value("Total", p.total),
                                     series: .value("Serie", "Puls"))
                                .foregroundStyle(Color.primary.opacity(0.6))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        }
                    }
                }
                RuleMark(y: .value("Mål", goal))
                    // Grå stiplet mållinje – samme som i widgets.
                    .foregroundStyle(Color.gray)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Mål \(Int(goal.rounded())) min").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
            }
            .chartXScale(domain: period)
            .chartYScale(domain: 0...yMax)
            .chartForegroundStyleScale([
                "Baggrund": HeartChart.backgroundColor.opacity(0.35),
                "Workout": HeartChart.workoutColor.opacity(0.45),
            ])
            .chartLegend(.hidden)
            .frame(height: 160)

            if source == .heartRate {
                // Fuld skriftstørrelse: på én linje, hvis der er plads – ellers én pr. linje.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { heartRateLegends }
                    VStack(alignment: .leading, spacing: 4) { heartRateLegends }
                }
                .font(.caption)
            } else {
                HStack(spacing: 12) {
                    legend(Self.appleColor, "Træningsring: \(Int(appleTotal.rounded())) min")
                    if showComparison {
                        dashed(.primary, "Pulszoner: \(Int(result.total.rounded())) min")
                    }
                }
                .font(.caption)
            }

            if source == .heartRate && showBreakdown {
            // Med én decimal, så regnestykket går op (afrundede hele minutter kan give 1 for lidt).
            Text("Moderat \(result.moderateMinutes, format: .number.precision(.fractionLength(1))) min × \(moderateWeight, format: .number.precision(.fractionLength(0...1))) + hård \(result.vigorousMinutes, format: .number.precision(.fractionLength(1))) min × \(vigorousWeight, format: .number.precision(.fractionLength(0...1))) = \(Int(result.total.rounded())) min")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Text("Mål: \(Int(weeklyGoal)) min pr. uge, tilpasset den valgte periode")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var heartRateLegends: some View {
        legend(HeartChart.backgroundColor, "Baggrundsaktivitet: \(Int(result.backgroundTotal.rounded())) min")
        legend(HeartChart.workoutColor, "Workouts: \(Int(result.workoutTotal.rounded())) min")
        if showComparison {
            line(Self.appleColor, "Træningsring: \(Int(appleTotal.rounded())) min")
        }
    }

    private func dashed(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Path { p in p.move(to: .init(x: 0, y: 5)); p.addLine(to: .init(x: 14, y: 5)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [4, 2]))
                .frame(width: 14, height: 10)
            Text(title)
        }
    }

    /// Fuldoptrukken streg (træningsringsminutterne som linje oven på grafen).
    private func line(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Capsule().fill(color).frame(width: 14, height: 2.5)
            Text(title)
        }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.6)).frame(width: 10, height: 10)
            Text(title)
        }
    }
}

/// Periodens workouts med point. Tryk på en workout for at zoome pulsgrafen ind på den.
struct WorkoutScoresView: View {
    let scores: [ActiveMinutes.WorkoutScore]
    var onSelect: (DateInterval) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workouts").font(.headline)
            ForEach(scores) { w in
                Button { onSelect(w.interval) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(w.interval.start, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                                Spacer()
                                Text("\(w.result.total, format: .number.precision(.fractionLength(1))) min").bold()
                            }
                            Text("\(Int((w.interval.duration / 60).rounded())) min · moderat \(w.result.moderateMinutes, format: .number.precision(.fractionLength(1))) · hård \(w.result.vigorousMinutes, format: .number.precision(.fractionLength(1))) · \(w.sampleCount) målinger")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Zoom pulsgrafen ind på denne workout")
            }
            if scores.isEmpty {
                Text("Ingen workouts i perioden").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
