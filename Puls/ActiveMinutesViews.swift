import SwiftUI
import HealthKit
import Charts

/// Graf over de kumulative aktive minutter i perioden, med målet som vandret linje.
struct ActiveMinutesChart: View {
    let result: ActiveMinutes
    /// Overskrift med tallet (slås fra, når den store hjerte-ring står ovenover).
    var showHeader = true
    let period: ClosedRange<Date>
    /// Zonerne med navne og faktorer (til regnestykket under grafen).
    let zones: HeartZones
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
                            .foregroundStyle(Brand.area(Self.appleColor))
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
                "Baggrund": Brand.area(HeartChart.backgroundColor, top: 0.5),
                "Workout": Brand.area(HeartChart.workoutColor, top: 0.55),
            ])
            // Rolig y-akse: få, svage linjer.
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.18))
                    AxisValueLabel()
                }
            }
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
            ZoneBreakdown(result: result, zones: zones)
            }
            Text("Mål: \(Int(weeklyGoal)) min pr. uge, tilpasset den valgte periode")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// "Moderat 12,3 min × 1 + hård 4,0 min × 2 = 20 min" – zoner, der tæller (× 0 udelades;
    /// ved 5 zoner også zoner uden minutter).
    static func breakdown(_ result: ActiveMinutes, zones: HeartZones) -> String {
        let one = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
        let weight = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1))
        var terms: [String] = []
        for i in zones.indices {
            let minutes = i < result.zoneMinutes.count ? result.zoneMinutes[i] : 0
            guard zones.weights[i] > 0, minutes > 0 || zones.model == .two else { continue }
            // To zoner: "Moderat … + hård …" (kun første med stort).
            let name = zones.model == .two && !terms.isEmpty ? zones.name(i).lowercased() : zones.name(i)
            terms.append("\(name) \(minutes.formatted(one)) min × \(zones.weights[i].formatted(weight))")
        }
        let sum = terms.isEmpty ? "0 min" : terms.joined(separator: " + ")
        return "\(sum) = \(Int(result.total.rounded())) min"
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
    let zones: HeartZones
    /// SF Symbol for workoutens type (fx løb, cykling, styrke), efter starttidspunkt.
    var icon: (Date) -> String = { _ in "figure.mixed.cardio" }
    var onSelect: (DateInterval) -> Void = { _ in }

    /// Minutter i de zoner, der tæller (fx "moderat 3,2", "Z4 1,0").
    private func zoneParts(_ r: ActiveMinutes) -> [String] {
        zones.indices.compactMap { i in
            let m = i < r.zoneMinutes.count ? r.zoneMinutes[i] : 0
            guard zones.weights[i] > 0, m > 0 || zones.model == .two else { return nil }
            let name = zones.model == .two ? zones.name(i).lowercased() : zones.name(i)
            return "\(name) \(m.formatted(.number.precision(.fractionLength(1))))"
        }
    }

    // Group (ikke VStack): i en List bliver overskriften og hver workout sin egen række.
    // Én høj række med alle workouts fik forkert højde og blev tegnet ind over rækken ovenover.
    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 2) {
                Text("Workouts").font(.headline)
                if !scores.isEmpty {
                    Text("Tryk på en workout for at se den i pulsgrafen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(scores) { w in
                Button { onSelect(w.interval) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                // Workout-farve og ikon, så det ses, at rækken kan trykkes på.
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
                                  + ["\(w.sampleCount) målinger"]).joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(HeartChart.workoutColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Zoom pulsgrafen ind på denne workout")
                .listRowSeparator(.hidden)
                // Lidt mere luft under det sidste kort, så det ikke rører kanten.
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: w.id == scores.last?.id ? 16 : 4, trailing: 16))
            }
            if scores.isEmpty {
                Text("Ingen workouts i perioden").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}



extension HKWorkoutActivityType {
    /// SF Symbol, der passer til workout-typen fra Sundhed.
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

/// Zone-bjælken under minutgrafen. Tryk for at se regnestykket ("Z1 … × 1 + Z3 … × 2 = N min").
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
        .accessibilityHint("Tryk for at se regnestykket")
    }
}

/// Den store hjerte-ring øverst i Overblik: periodens Heart Minutes mod målet.
struct HeroRing: View {
    let total: Double
    let goal: Double
    /// Ny periode: ringen tæller op fra 0 igen.
    var period: DateInterval? = nil
    @State private var countedPeriod: DateInterval?
    /// Andelen, ringen viser lige nu (tælles op fra 0 eller fra den forrige værdi).
    @State private var shown = 0.0
    /// Øges, når appen åbnes igen, så ringen fyldes op forfra.
    @State private var run = 0
    @State private var wasInBackground = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private var fraction: Double { goal > 0 ? max(0, total / goal) : 0 }
    private var reached: Bool { goal > 0 && total >= goal }
    /// Tallet i midten tæller med op, så det passer til ringen undervejs.
    private var shownMinutes: Int { goal > 0 ? Int((shown * goal).rounded()) : Int(total.rounded()) }

    var body: some View {
        VStack(spacing: 6) {
            AnimatedHeartRing(fraction: shown, value: "\(shownMinutes)")
                .frame(width: 170, height: 170)
                // Mørk tilstand: ringen lyser lidt, som på uret.
                .shadow(color: colorScheme == .dark ? Brand.accent.opacity(0.4) : .clear, radius: 14)
            HStack(spacing: 6) {
                Text("af \(Int(goal.rounded())) min · \(Int((fraction * 100).rounded())) %")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if reached {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        // Ved visning, ny periode/nye data og når appen åbnes igen. Animeres trin for trin (i stedet
        // for withAnimation), så det virker pålideligt inde i en liste.
        .task(id: "\(fraction)-\(run)-\(period?.start.timeIntervalSince1970 ?? 0)-\(period?.end.timeIntervalSince1970 ?? 0)") {
            if period != countedPeriod { countedPeriod = period; shown = 0 }
            await fill(to: fraction)
        }
        .onChange(of: scenePhase) { _, phase in
            // Kun efter baggrunden – ikke fx når Kontrolcenter lukkes.
            if phase == .background { wasInBackground = true }
            if phase == .active && wasInBackground { wasInBackground = false; shown = 0; run += 1 }
        }
        .accessibilityElement(children: .combine)
    }

    /// Konstant fart: én hel omgang (100 %) pr. sekund, så 300 % tager 3 sekunder – ikke en fast tid.
    private func fill(to target: Double) async {
        let start = shown
        let lapsPerSecond = 1.0
        let duration = max(abs(target - start) / lapsPerSecond, 0.01)
        let begin = Date.now
        while !Task.isCancelled {
            let t = min(Date.now.timeIntervalSince(begin) / duration, 1)
            shown = start + (target - start) * t
            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}
