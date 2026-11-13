import SwiftUI
import Charts
import HealthKit

extension HeartZones {
    /// Farve pr. zone (se `rgb`). Zoner, der ikke tæller (× 0), er grå.
    func color(_ i: Int) -> Color {
        let c = rgb(i)
        return Color(red: c[0], green: c[1], blue: c[2])
    }
}

/// Pulsgraf med AHA-zoner som baggrund, en prik pr. måling og zoom med to fingre.
/// Standardvisning passer til målingerne. Man kan zoome ud til hele den valgte periode
/// (tid) og 0…maks-puls (puls); y-aksen glider gradvist derud, mens man zoomer ud.
struct HeartChart: View {
    let samples: [HRSample]
    let zones: HeartZones
    /// Den valgte periode (dagen eller træningen) = maks zoom ud på tidsaksen.
    let period: ClosedRange<Date>
    /// Sættes udefra (fx tryk på en workout) for at zoome ind på et tidsrum.
    var focus: FocusRequest? = nil
    /// Heart Minutes optjent i et tidsrum – vises, når man har zoomet ind.
    var heartMinutes: ((Date, Date) -> Double)? = nil

    /// Ønske om at zoome til et tidsrum; nyt id hver gang, så samme workout kan vælges igen.
    struct FocusRequest: Equatable {
        let interval: DateInterval
        let id = UUID()
    }

    @State private var visibleLength: TimeInterval?   // nil = tilpasset målingerne
    @State private var pinchBase: TimeInterval?
    @State private var scrollX = Date.distantPast
    @State private var selectedDate: Date?
    @State private var dragStart: Date?
    @State private var chartWidth: CGFloat = 300
    @State private var showLegend = false

    private static let minLength: TimeInterval = 120

    private var dataStart: Date { samples.first?.date ?? period.lowerBound }
    private var dataEnd: Date { samples.last?.date ?? period.upperBound }
    private var periodStart: Date { min(period.lowerBound, dataStart) }
    private var periodEnd: Date { max(period.upperBound, dataEnd, periodStart.addingTimeInterval(Self.minLength)) }
    private var periodLength: TimeInterval { periodEnd.timeIntervalSince(periodStart) }
    /// Standard-zoom: lige netop alle målinger.
    private var fitLength: TimeInterval {
        min(periodLength, max(Self.minLength, dataEnd.timeIntervalSince(dataStart)))
    }

    private func clampedScroll(_ x: Date, length: TimeInterval) -> Date {
        max(periodStart, min(periodEnd.addingTimeInterval(-length), x))
    }

    /// Målingerne i det synlige vindue (binær søgning, ikke filter over alle målinger).
    private func visibleSamples(from: Date, length: TimeInterval) -> ArraySlice<HRSample> {
        let inside = samples.slice(from: from, to: from.addingTimeInterval(length))
        return inside.isEmpty ? samples[...] : inside
    }

    /// Nøgle der ændrer sig, når der kommer nye målinger – billig at sammenligne
    /// (at sammenligne hele arrayet ved hver opdatering var meget langsomt).
    private var samplesKey: [AnyHashable] {
        [samples.count, samples.first?.id, samples.last?.id, period.lowerBound, period.upperBound]
    }

    var body: some View {
        let length = visibleLength ?? fitLength
        let from = clampedScroll(scrollX, length: length)
        let to = from.addingTimeInterval(length)
        let visible = visibleSamples(from: from, length: length)
        // 0 ved standard-zoom, 1 ved maks zoom ud.
        let zoomOut = periodLength > fitLength
            ? max(0, min(1, (length - fitLength) / (periodLength - fitLength))) : 0
        let y = Self.yDomain(Self.sampledValues(visible), maxHR: zones.maxHR, zoomOut: zoomOut)
        let (drawn, thinning) = Self.thinned(samplesNear(from: from, length: length))
        let segments = HRSample.segments(drawn)
        let motionStrips = Self.motionStrips(drawn)
        let exerciseStrips = Self.exerciseStrips(drawn)
        let bridgedStrips = Self.strips(drawn) { $0.bridgedActive }
        // Prikker (og tryk på punkter) først når man er zoomet langt ind.
        let showDots = thinning == 1 && visible.count <= Self.maxDotsVisible
        let selected = showDots ? selectedDate.flatMap { Self.nearest(to: $0, in: Array(visible)) } : nil
        VStack(alignment: .leading, spacing: 8) {
            // Info om det valgte punkt vises over grafen (en annotation inde i grafen blev klippet væk).
            if let selected {
                HStack(spacing: 8) {
                    Text("\(Int(selected.bpm.rounded())) bpm").font(.headline)
                    Text(selected.date, format: periodLength > 86_400
                         ? .dateTime.day().month(.abbreviated).hour().minute().second()
                         : .dateTime.hour().minute().second())
                    if selected.motion != .unknown {
                        Text(selected.motion.name)
                            .foregroundStyle(selected.motion == .active ? Self.activeColor : .secondary)
                    }
                    if selected.inWorkout {
                        Text("Workout").foregroundStyle(Self.workoutColor)
                    }
                    if selected.bridgedActive {
                        Text("Udfyldt").foregroundStyle(Self.activeColor)
                    }
                    if selected.inExercise {
                        Text("Træningsring").foregroundStyle(Self.exerciseColor)
                    }
                    Spacer()
                    Button { selectedDate = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                // Altid én linje: skrump teksten hellere end at bryde ord over.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            // Zoom-knappen står lige over grafens øverste højre hjørne.
            HStack {
                // Hvor mange Heart Minutes der er optjent i det viste område (følger zoom og scroll).
                if let heartMinutes {
                    Text("\(heartMinutes(from, to), format: .number.precision(.fractionLength(1))) Heart Minutes i visningen")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if visibleLength != nil && abs(length - fitLength) > 1 {
                    Button("Nulstil zoom") { reset() }
                        .buttonStyle(.borderless)
                } else {
                    Text("Knib for at zoome").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            Chart {
                ForEach(zones.indices, id: \.self) { i in
                    let range = zones.bpmRange(i)
                    RectangleMark(
                        xStart: .value("Start", from), xEnd: .value("Slut", to),
                        yStart: .value("Fra", i == 0 ? min(0, y.lowerBound) : range.lowerBound),
                        yEnd: .value("Til", min(range.upperBound, max(y.upperBound, zones.maxHR) + 50)))
                        .foregroundStyle(zones.color(i).opacity(0.12))
                }
                // Bånd i bunden: Apples vurdering af aktiv / i ro.
                let bandTop = y.lowerBound + (y.upperBound - y.lowerBound) * 0.04
                ForEach(motionStrips) { strip in
                    RectangleMark(xStart: .value("Fra", strip.start), xEnd: .value("Til", strip.end),
                                  yStart: .value("Bund", y.lowerBound), yEnd: .value("Top", bandTop))
                        .foregroundStyle(strip.motion == .active ? Self.activeColor : Self.sedentaryColor)
                }
                // Udfyldte huller ("Udfyld korte huller") i samme bånd, lysere blå.
                ForEach(bridgedStrips) { strip in
                    RectangleMark(xStart: .value("Fra", strip.start), xEnd: .value("Til", strip.end),
                                  yStart: .value("Bund", y.lowerBound), yEnd: .value("Top", bandTop))
                        .foregroundStyle(Self.bridgedColor)
                }
                // Bånd lige over: hvor Apples grønne træningsring tæller minutter.
                let exerciseBottom = bandTop + (y.upperBound - y.lowerBound) * 0.01
                let exerciseTop = exerciseBottom + (y.upperBound - y.lowerBound) * 0.04
                ForEach(exerciseStrips) { strip in
                    RectangleMark(xStart: .value("Fra", strip.start), xEnd: .value("Til", strip.end),
                                  yStart: .value("Bund", exerciseBottom), yEnd: .value("Top", exerciseTop))
                        .foregroundStyle(Self.exerciseColor)
                }
                ForEach(Array(drawn.enumerated()), id: \.element.id) { i, s in
                    let color = s.inWorkout ? Self.workoutColor : Self.backgroundColor
                    LineMark(x: .value("Tid", s.date), y: .value("BPM", s.bpm),
                             series: .value("Serie", segments[i]))
                        .foregroundStyle(color.opacity(0.6))
                        .interpolationMethod(.monotone)
                    if showDots {
                        PointMark(x: .value("Tid", s.date), y: .value("BPM", s.bpm))
                            .foregroundStyle(color)
                            .symbolSize(20)
                    }
                }
                if let selected {
                    RuleMark(x: .value("Valgt", selected.date))
                        .foregroundStyle(.secondary.opacity(0.5))
                    PointMark(x: .value("Tid", selected.date), y: .value("BPM", selected.bpm))
                        .foregroundStyle(selected.inWorkout ? Self.workoutColor : Self.backgroundColor)
                        .symbolSize(90)
                }
            }
            // Kun det synlige vindue lægges ud. (Swift Charts' egen scroll lagde hele perioden ud
            // – ved stor zoom på en lang periode blev det millioner af punkter bredt, og grafen frøs.)
            .chartXScale(domain: from...to)
            .chartYScale(domain: y)
            // Y-aksen: altid zonegrænserne; flere tal, når man er zoomet ind (lille pulsspænd).
            .chartYAxis {
                AxisMarks(position: .trailing, values: Self.yTicks(zones: zones, in: y)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let bpm = value.as(Double.self) { Text("\(Int(bpm.rounded()))") }
                    }
                }
            }
            .chartPlotStyle { $0.clipped() }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: length > 2 * 86_400
                                   ? .dateTime.day().month(.abbreviated)
                                   : .dateTime.hour().minute())
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartGesture { proxy in
                SpatialTapGesture().onEnded { tap in
                    if showDots { proxy.selectXValue(at: tap.location.x) } else { selectedDate = nil }
                }
            }
            .frame(height: 240)
            .overlay {
                if drawn.isEmpty {
                    Text("Ingen målinger i dette udsnit").font(.caption).foregroundStyle(.secondary)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
            // Egen panorering: træk vandret for at flytte tidsvinduet.
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { g in
                        guard abs(g.translation.width) > abs(g.translation.height) else { return }
                        if dragStart == nil { dragStart = from }
                        let plotWidth = max(Double(chartWidth) - 40, 1)   // minus y-aksens tekster
                        let dt = -Double(g.translation.width) / plotWidth * length
                        scrollX = clampedScroll((dragStart ?? from).addingTimeInterval(dt), length: length)
                    }
                    .onEnded { _ in dragStart = nil })
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { gesture in
                        if pinchBase == nil { pinchBase = length }
                        let center = from.addingTimeInterval(length / 2)
                        let newLength = min(periodLength,
                                            max(Self.minLength, (pinchBase ?? length) / gesture.magnification))
                        visibleLength = newLength
                        scrollX = clampedScroll(center.addingTimeInterval(-newLength / 2), length: newLength)
                    }
                    .onEnded { _ in pinchBase = nil })

            // Forklaringen er foldet sammen, så grafen får ro: kurven, baggrunden og båndene i bunden.
            DisclosureGroup(isExpanded: $showLegend) {
              VStack(alignment: .leading, spacing: 8) {
                legendGroup("Kurven") {
                    legendDot(Self.backgroundColor, "Baggrundsaktivitet")
                    legendDot(Self.workoutColor, "Workout")
                }
                legendGroup("Baggrund (pulszoner)") {
                    ForEach(zones.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(zones.color(i).opacity(0.4))
                                .frame(width: 10, height: 10)
                            Text(zones.name(i))
                        }
                    }
                }
                legendGroup("Bånd i bunden (aktivitet)") {
                    legendBar(Self.activeColor, "Aktiv")
                    legendBar(Self.sedentaryColor, "I ro")
                    legendBar(Self.exerciseColor, "Træningsring")
                    if samples.contains(where: \.bridgedActive) {
                        legendBar(Self.bridgedColor, "Udfyldt")
                    }
                }
                // Målingerne: antal og sampling i visningen.
                VStack(alignment: .leading, spacing: 3) {
                    Text("Målinger").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    if let hz = visible.samplingRateHz {
                        Text("\(samples.count) målinger · sampling i visning: \(hz, format: .number.precision(.significantDigits(2))) Hz · ca. 1 måling pr. \(Self.interval(1 / hz))")
                    } else {
                        Text("\(samples.count) målinger")
                    }
                }
                .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 4)
            } label: {
                Label("Forklaring", systemImage: "info.circle")
            }
            .font(.caption)
        }
        .onAppear { reset() }
        .onChange(of: samplesKey) { reset() }
        .onChange(of: focus) { _, f in if let f { zoom(to: f.interval) } }
    }

    static let backgroundColor = Color.red
    static let workoutColor = Color.purple
    static let maxDrawnPoints = 1500
    /// Højst så mange synlige målinger, før prikkerne vises.
    static let maxDotsVisible = 120

    /// Målingen tættest på et tidspunkt.
    static func nearest(to date: Date, in samples: [HRSample]) -> HRSample? {
        samples.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    static let activeColor = Color.blue
    static let sedentaryColor = Color.gray.opacity(0.5)
    static let exerciseColor = Color.green
    static let bridgedColor = Color.blue.opacity(0.4)

    struct ExerciseStrip: Identifiable, Equatable {
        let id: Int
        let start: Date
        let end: Date
    }

    /// Slår målinger, hvor træningsringen tæller, sammen til bånd (samme regler som bevægelsesbåndet).
    static func exerciseStrips(_ samples: [HRSample]) -> [ExerciseStrip] {
        strips(samples) { $0.inExercise }
    }

    /// Slår målinger, der opfylder `include`, sammen til bånd (samme regler som bevægelsesbåndet).
    static func strips(_ samples: [HRSample], where include: (HRSample) -> Bool) -> [ExerciseStrip] {
        var strips: [ExerciseStrip] = []
        for (i, s) in samples.enumerated() where include(s) {
            let next = i + 1 < samples.count ? samples[i + 1].date : nil
            let end = next.flatMap { $0.timeIntervalSince(s.date) <= HRSample.lineBreakGap ? $0 : nil }
                ?? s.date.addingTimeInterval(60)
            if let last = strips.last, last.end >= s.date {
                strips[strips.count - 1] = ExerciseStrip(id: last.id, start: last.start, end: end)
            } else {
                strips.append(ExerciseStrip(id: strips.count, start: s.date, end: end))
            }
        }
        return strips
    }

    /// En lille overskrift og forklaringerne under den.
    private func legendGroup<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 12) { content() }
        }
    }

    private func legendBar(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            // Farvet kasse, ligesom båndene i bunden af grafen.
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 14, height: 8)
            Text(title)
        }
    }

    struct MotionStrip: Identifiable, Equatable {
        let id: Int
        let start: Date
        let end: Date
        let motion: MotionContext
    }

    /// Slår målinger med samme bevægelseskontekst sammen til bånd. Ukendt kontekst vises ikke.
    /// Et bånd strækker sig til næste måling (højst en time), ellers ét minut.
    static func motionStrips(_ samples: [HRSample]) -> [MotionStrip] {
        var strips: [MotionStrip] = []
        for (i, s) in samples.enumerated() where s.motion != .unknown {
            let next = i + 1 < samples.count ? samples[i + 1].date : nil
            let end = next.flatMap { $0.timeIntervalSince(s.date) <= HRSample.lineBreakGap ? $0 : nil }
                ?? s.date.addingTimeInterval(60)
            if let last = strips.last, last.motion == s.motion, last.end >= s.date {
                strips[strips.count - 1] = MotionStrip(id: last.id, start: last.start, end: end, motion: s.motion)
            } else {
                strips.append(MotionStrip(id: strips.count, start: s.date, end: end, motion: s.motion))
            }
        }
        return strips
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            // En streg, som kurven i grafen.
            Capsule().fill(color.opacity(0.8)).frame(width: 14, height: 3)
            Text(title)
        }
    }

    /// Målingerne omkring det synlige vindue (lidt ekstra i begge sider, så man kan swipe).
    private func samplesNear(from: Date, length: TimeInterval) -> ArraySlice<HRSample> {
        samples.slice(from: from.addingTimeInterval(-length), to: from.addingTimeInterval(2 * length))
    }

    /// Pulsværdier til y-aksen; ved mange målinger kun et udsnit (min/max er tæt nok).
    static func sampledValues(_ samples: ArraySlice<HRSample>, max: Int = 3000) -> [Double] {
        guard samples.count > max else { return samples.map(\.bpm) }
        let step = samples.count / max + 1
        return stride(from: samples.startIndex, to: samples.endIndex, by: step).map { samples[$0].bpm }
    }

    /// Tynder ud til højst `maxDrawnPoints`, så lange perioder stadig tegnes hurtigt.
    /// Returnerer også hvor mange målinger hver tegnet prik står for.
    static func thinned<C: RandomAccessCollection>(_ samples: C, max: Int = maxDrawnPoints) -> ([HRSample], Int)
    where C.Element == HRSample, C.Index == Int {
        guard samples.count > max else { return (Array(samples), 1) }
        let step = Int((Double(samples.count) / Double(max)).rounded(.up))
        return (stride(from: samples.startIndex, to: samples.endIndex, by: step).map { samples[$0] }, step)
    }

    /// Zoomer ind, så tidsrummet (med lidt luft på hver side) fylder grafen.
    private func zoom(to interval: DateInterval) {
        let margin = max(30, interval.duration * 0.05)
        let length = min(periodLength, max(Self.minLength, interval.duration + 2 * margin))
        visibleLength = length
        selectedDate = nil
        scrollX = clampedScroll(interval.start.addingTimeInterval(-margin), length: length)
    }

    private func reset() {
        visibleLength = nil
        selectedDate = nil
        scrollX = clampedScroll(dataStart, length: fitLength)
    }

    /// Y-akse: målingerne ± 5 ved zoomOut 0, glider lineært mod 0…maks-puls ved zoomOut 1.
    /// Tal på y-aksen: zonegrænserne inden for visningen, plus runde tal (hver 10. eller 5. bpm),
    /// når spændet er lille nok til, at der er plads. Tal tæt på en grænse udelades.
    static func yTicks(zones: HeartZones, in y: ClosedRange<Double>) -> [Double] {
        let bounds = zones.thresholds.map { $0.rounded() }.filter { y.contains($0) }
        let span = y.upperBound - y.lowerBound
        let step: Double? = span <= 40 ? 5 : span <= 80 ? 10 : nil
        var ticks = bounds
        if let step {
            var v = (y.lowerBound / step).rounded(.up) * step
            while v <= y.upperBound {
                if bounds.allSatisfy({ abs($0 - v) >= step * 0.6 }) { ticks.append(v) }
                v += step
            }
        }
        return ticks.sorted()
    }

    static func yDomain(_ values: [Double], maxHR: Double, zoomOut: Double) -> ClosedRange<Double> {
        let low = (values.min() ?? 60) - 5
        let high = max((values.max() ?? 100) + 5, low + 20)
        let fullHigh = max(maxHR, high)
        let t = max(0, min(1, zoomOut))
        return (low + (0 - low) * t)...(high + (fullHigh - high) * t)
    }
}

extension HeartChart {
    static func interval(_ seconds: Double) -> String {
        seconds < 90 ? "\(Int(seconds.rounded())) s" : "\(Int((seconds / 60).rounded())) min"
    }
}

struct StatsRow: View {
    let stats: HeartStats
    var body: some View {
        HStack {
            stat("Min", stats.min); Spacer()
            stat("Gns.", stats.avg); Spacer()
            stat("Max", stats.max)
        }
    }
    private func stat(_ title: String, _ value: Int) -> some View {
        VStack {
            Text("\(value)").font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Periodevælger øverst i Overblik.
struct PeriodHeader: View {
    @Binding var interval: DateInterval
    @State private var showPicker = false

    var body: some View {
        HStack {
            Button { interval = Period.shifted(interval, by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            // Tydelig knap: kalenderikon + pil ned + baggrund, så det ses at perioden kan ændres.
            Button { showPicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(Period.label(interval))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .padding(.vertical, 2)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityHint("Vælg periode")
            Spacer()
            Button { interval = Period.shifted(interval, by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(interval.end > .now)
        }
        .buttonStyle(.borderless)
        .imageScale(.large)
        .sheet(isPresented: $showPicker) { PeriodPicker(interval: $interval) }
    }
}

/// Overblik: Heart Minutes øverst, derefter pulsen og workouts i detaljer.
/// (Widgets er de simple; appen har detaljerne.)
struct OverviewView: View {
    @Environment(HealthManager.self) private var health
    @Binding var interval: DateInterval
    /// Øges, når appen åbnes fra en widget: rul op til minutgrafen.
    var showMinutes = 0
    @State private var focus: HeartChart.FocusRequest?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                // Tre "vinduer" (sektioner) oven på baggrunden: Heart Minutes, pulsmålinger og workouts.
                let stats = HeartStats(health.shownSamples)
                let result = ActiveMinutes(health.minuteSamples, config: health.minutesConfig)
                let total = health.minutesSource == .appleExercise
                    ? (health.applePoints.last?.total ?? 0) : result.total
                let goal = ActiveMinutes.scaledGoal(weekly: Double(health.weeklyGoal), duration: interval.duration)
                Section {
                    PeriodHeader(interval: $interval)
                        .id("top")
                    // Hero: den store hjerte-ring med periodens tal.
                    HeroRing(total: total, goal: goal)
                        .listRowSeparator(.hidden)
                    if stats != nil || health.minutesSource == .appleExercise {
                        ActiveMinutesChart(
                            result: result,
                            showHeader: false,
                            period: interval.start...interval.end,
                            zones: health.zones,
                            weeklyGoal: Double(health.weeklyGoal),
                            applePoints: health.applePoints,
                            source: health.minutesSource,
                            showComparison: health.showComparison)
                    } else {
                        NoDataView()
                    }
                    if stats != nil && health.showUnmarkedHint {
                        UnmarkedHint(info: health.unmarked,
                                     turnOff: { health.onlyWhenActive = false },
                                     ignore: { health.ignoreUnmarkedSources() })
                    }
                }

                if let stats {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pulsmålinger").font(.headline)
                            StatsRow(stats: stats)
                        }
                        .id("pulsechart")
                        // Med pauser markeres de udfyldte målinger, så båndet i bunden kan vise dem.
                        HeartChart(samples: ActiveMinutes.bridgingActive(health.shownSamples, config: health.minutesConfig),
                                   zones: health.zones,
                                   period: interval.start...interval.end,
                                   focus: focus,
                                   heartMinutes: { a, b in
                                       ActiveMinutes.credit(in: health.minuteSamples, from: a, to: b,
                                                            config: health.minutesConfig)
                                   })
                    }

                    if !health.periodWorkouts.isEmpty && health.includeWorkouts {
                        Section {
                            WorkoutScoresView(scores: ActiveMinutes.perWorkout(
                                health.minuteSamples, workouts: health.periodWorkouts, config: health.minutesConfig),
                                zones: health.zones,
                                icon: { health.workoutTypes[$0]?.symbolName ?? "figure.mixed.cardio" }
                            ) { workout in
                                focus = .init(interval: workout)
                                withAnimation { proxy.scrollTo("pulsechart", anchor: .top) }
                            }
                        }
                    }
                }
            }
            .fontDesign(.rounded)
            .onChange(of: showMinutes) { withAnimation { proxy.scrollTo("top", anchor: .top) } }
            }
            // Ingen stor titel: perioden starter helt oppe.
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: interval) { focus = nil }
            .refreshable { await health.loadPeriod(interval) }
        }
    }
}

/// Når der ikke er noget at vise.
struct NoDataView: View {
    @Environment(HealthManager.self) private var health

    var body: some View {
        if !health.includeBackground && !health.includeWorkouts {
            ContentUnavailableView("Ingen målinger valgt", systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Slå baggrundsmålinger eller workouts til under Indstillinger → Avanceret."))
        } else {
            ContentUnavailableView("Ingen pulsdata", systemImage: "heart.slash",
                description: Text("Tjek at Heart Minutes har adgang i Sundhed-appen."))
        }
    }
}

/// Besked når "Kun når aktiv" sorterer mange baggrundsmålinger fra, fordi de ikke har
/// Apple Watchs markering for aktiv/i ro (fx fra en ring eller en anden app).
struct UnmarkedHint: View {
    let info: HRSample.UnmarkedInfo
    let turnOff: () -> Void
    let ignore: () -> Void

    private var sourceText: String {
        let names = info.sources.prefix(3).joined(separator: ", ")
        return info.sources.count > 3 ? names + " m.fl." : names
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Målinger tæller ikke med", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text("\(Int((info.fraction * 100).rounded())) % af dine baggrundsmålinger (fra \(sourceText)) har ingen markering for aktiv/i ro, så de tæller ikke med »Kun når aktiv«. Markeringen kommer kun fra Apple Watch.")
                .font(.callout)
            HStack {
                Button("Slå »Kun når aktiv« fra", action: turnOff)
                    .buttonStyle(.borderedProminent)
                Button("Ignorér", action: ignore)
                    .buttonStyle(.bordered)
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }
}

/// Menu hvor man frit vælger perioden (fra/til med dato og klokkeslæt).
struct PeriodPicker: View {
    @Binding var interval: DateInterval
    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date

    init(interval: Binding<DateInterval>) {
        _interval = interval
        _start = State(initialValue: interval.wrappedValue.start)
        _end = State(initialValue: interval.wrappedValue.end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Fra", selection: $start, in: ...Date.now)
                    DatePicker("Til", selection: $end, in: start.addingTimeInterval(60)...)
                } footer: {
                    Text("Varighed: \(Duration.seconds(end.timeIntervalSince(start)), format: .units(allowed: [.days, .hours, .minutes], width: .wide))")
                }
                Section {
                    quick("I dag", Period.day())
                    quick("Denne uge", Period.thisWeek())
                    // Hele måneden, ligesom "Denne uge" er hele ugen.
                    quick("Denne måned", Calendar.current.dateInterval(of: .month, for: .now) ?? Period.thisWeek())
                    quick("Seneste 24 timer", DateInterval(start: .now.addingTimeInterval(-86_400), end: .now))
                    quick("Seneste 7 dage", DateInterval(start: .now.addingTimeInterval(-7 * 86_400), end: .now))
                    quick("Seneste måned", DateInterval(
                        start: Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now.addingTimeInterval(-30 * 86_400),
                        end: .now))
                    quick("Seneste år", DateInterval(
                        start: Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now.addingTimeInterval(-365 * 86_400),
                        end: .now))
                } header: {
                    Text("Hurtigvalg")
                } footer: {
                    Text("I dag, denne uge og denne måned er faste perioder: målet skal nås, inden perioden er omme, og så starter du forfra.\n\n»Seneste …« er et rullende vindue, der hele tiden flytter sig med tiden. Her handler det om at holde dig over målet hele tiden – gamle minutter falder ud, efterhånden som nye kommer til.")
                }
            }
            .navigationTitle("Vælg periode")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: start) { if end <= start { end = start.addingTimeInterval(3600) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuller") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Vis") {
                        interval = DateInterval(start: start, end: end)
                        dismiss()
                    }
                    .disabled(end <= start)
                }
            }
        }
    }

    private func quick(_ title: String, _ value: DateInterval) -> some View {
        Button(title) { start = value.start; end = value.end }
    }
}
