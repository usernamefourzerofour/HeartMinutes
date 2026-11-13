import SwiftUI
import Charts
import HealthKit

extension HeartZones {
    /// Colour per zone (see `rgb`). Zones that don't count (× 0) are grey.
    func color(_ i: Int) -> Color {
        let c = rgb(i)
        return Color(red: c[0], green: c[1], blue: c[2])
    }
}

/// Heart rate chart with the zones as background, a dot per measurement and two-finger zoom. The default view fits the
/// measurements. You can zoom out to the whole selected period (time) and 0…max heart rate (heart rate); the y axis
/// moves out gradually while zooming out.
struct HeartChart: View {
    let samples: [HRSample]
    let zones: HeartZones
    /// The selected period (the day or the workout) = maximum zoom out on the time axis.
    let period: ClosedRange<Date>
    /// Set from outside (e.g. tapping a workout) to zoom in on a time range.
    var focus: FocusRequest? = nil
    /// Heart Minutes earned in a time range – shown when zoomed in.
    var heartMinutes: ((Date, Date) -> Double)? = nil

    /// Request to zoom to a time range; a new id each time, so the same workout can be selected again.
    struct FocusRequest: Equatable {
        let interval: DateInterval
        let id = UUID()
    }

    @State private var visibleLength: TimeInterval?   // nil = fitted to the measurements
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
    /// Default zoom: just all measurements.
    private var fitLength: TimeInterval {
        min(periodLength, max(Self.minLength, dataEnd.timeIntervalSince(dataStart)))
    }

    private func clampedScroll(_ x: Date, length: TimeInterval) -> Date {
        max(periodStart, min(periodEnd.addingTimeInterval(-length), x))
    }

    /// The measurements in the visible window (binary search, not a filter over all measurements).
    private func visibleSamples(from: Date, length: TimeInterval) -> ArraySlice<HRSample> {
        let inside = samples.slice(from: from, to: from.addingTimeInterval(length))
        return inside.isEmpty ? samples[...] : inside
    }

    /// A key that changes when new measurements arrive – cheap to compare (comparing the whole array on every update
    /// was very slow).
    private var samplesKey: [AnyHashable] {
        [samples.count, samples.first?.id, samples.last?.id, period.lowerBound, period.upperBound]
    }

    var body: some View {
        let length = visibleLength ?? fitLength
        let from = clampedScroll(scrollX, length: length)
        let to = from.addingTimeInterval(length)
        let visible = visibleSamples(from: from, length: length)
        // 0 at default zoom, 1 at maximum zoom out.
        let zoomOut = periodLength > fitLength
            ? max(0, min(1, (length - fitLength) / (periodLength - fitLength))) : 0
        let y = Self.yDomain(Self.sampledValues(visible), maxHR: zones.maxHR, zoomOut: zoomOut)
        let (drawn, thinning) = Self.thinned(samplesNear(from: from, length: length))
        let segments = HRSample.segments(drawn)
        let motionStrips = Self.motionStrips(drawn)
        let exerciseStrips = Self.exerciseStrips(drawn)
        let bridgedStrips = Self.strips(drawn) { $0.bridgedActive }
        // Dots (and tapping points) only when zoomed in far.
        let showDots = thinning == 1 && visible.count <= Self.maxDotsVisible
        let selected = showDots ? selectedDate.flatMap { Self.nearest(to: $0, in: Array(visible)) } : nil
        VStack(alignment: .leading, spacing: 8) {
            // Info about the selected point is shown above the chart (an annotation inside the chart got clipped).
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
                        Text("Filled in").foregroundStyle(Self.activeColor)
                    }
                    if selected.inExercise {
                        Text("Exercise ring").foregroundStyle(Self.exerciseColor)
                    }
                    Spacer()
                    Button { selectedDate = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
                // Always one line: shrink the text rather than break words.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            // The zoom button sits just above the chart's top right corner.
            HStack {
                // How many Heart Minutes were earned in the visible area (follows zoom and scrolling).
                if let heartMinutes {
                    Text("\(heartMinutes(from, to), format: .number.precision(.fractionLength(1))) Heart Minutes in view")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if visibleLength != nil && abs(length - fitLength) > 1 {
                    Button("Reset zoom") { reset() }
                        .buttonStyle(.borderless)
                } else {
                    Text("Pinch to zoom").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            Chart {
                ForEach(zones.indices, id: \.self) { i in
                    let range = zones.bpmRange(i)
                    RectangleMark(
                        xStart: .value("Start", from), xEnd: .value("End", to),
                        yStart: .value("From", i == 0 ? min(0, y.lowerBound) : range.lowerBound),
                        yEnd: .value("To", min(range.upperBound, max(y.upperBound, zones.maxHR) + 50)))
                        .foregroundStyle(zones.color(i).opacity(0.12))
                }
                // Band at the bottom: Apple's judgement of active / resting.
                let bandTop = y.lowerBound + (y.upperBound - y.lowerBound) * 0.04
                ForEach(motionStrips) { strip in
                    RectangleMark(xStart: .value("From", strip.start), xEnd: .value("To", strip.end),
                                  yStart: .value("Bottom", y.lowerBound), yEnd: .value("Top", bandTop))
                        .foregroundStyle(strip.motion == .active ? Self.activeColor : Self.sedentaryColor)
                }
                // Filled gaps ("Fill short gaps") in the same band, lighter blue.
                ForEach(bridgedStrips) { strip in
                    RectangleMark(xStart: .value("From", strip.start), xEnd: .value("To", strip.end),
                                  yStart: .value("Bottom", y.lowerBound), yEnd: .value("Top", bandTop))
                        .foregroundStyle(Self.bridgedColor)
                }
                // Band just above: where Apple's green Exercise ring counts minutes.
                let exerciseBottom = bandTop + (y.upperBound - y.lowerBound) * 0.01
                let exerciseTop = exerciseBottom + (y.upperBound - y.lowerBound) * 0.04
                ForEach(exerciseStrips) { strip in
                    RectangleMark(xStart: .value("From", strip.start), xEnd: .value("To", strip.end),
                                  yStart: .value("Bottom", exerciseBottom), yEnd: .value("Top", exerciseTop))
                        .foregroundStyle(Self.exerciseColor)
                }
                ForEach(Array(drawn.enumerated()), id: \.element.id) { i, s in
                    let color = s.inWorkout ? Self.workoutColor : Self.backgroundColor
                    LineMark(x: .value("Time", s.date), y: .value("BPM", s.bpm),
                             series: .value("Series", segments[i]))
                        .foregroundStyle(color.opacity(0.6))
                        .interpolationMethod(.monotone)
                    if showDots {
                        PointMark(x: .value("Time", s.date), y: .value("BPM", s.bpm))
                            .foregroundStyle(color)
                            .symbolSize(20)
                    }
                }
                if let selected {
                    RuleMark(x: .value("Selected", selected.date))
                        .foregroundStyle(.secondary.opacity(0.5))
                    PointMark(x: .value("Time", selected.date), y: .value("BPM", selected.bpm))
                        .foregroundStyle(selected.inWorkout ? Self.workoutColor : Self.backgroundColor)
                        .symbolSize(90)
                }
            }
            // Only the visible window is laid out. (Swift Charts' own scrolling laid out the whole period – at high
            // zoom on a long period that became millions of points wide and the chart froze.)
            .chartXScale(domain: from...to)
            .chartYScale(domain: y)
            // Y axis: always the zone limits; more numbers when zoomed in (small heart rate span).
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
                    Text("No measurements in this range").font(.caption).foregroundStyle(.secondary)
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
            // Own panning: drag horizontally to move the time window.
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { g in
                        guard abs(g.translation.width) > abs(g.translation.height) else { return }
                        if dragStart == nil { dragStart = from }
                        let plotWidth = max(Double(chartWidth) - 40, 1)   // minus the y axis labels
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

            // The legend is collapsed so the chart stays calm: the curve, the background and the bands at the bottom.
            DisclosureGroup(isExpanded: $showLegend) {
              VStack(alignment: .leading, spacing: 8) {
                legendGroup("The curve") {
                    legendDot(Self.backgroundColor, "Background activity")
                    legendDot(Self.workoutColor, "Workout")
                }
                legendGroup("Background (heart rate zones)") {
                    ForEach(zones.indices, id: \.self) { i in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(zones.color(i).opacity(0.4))
                                .frame(width: 10, height: 10)
                            Text(zones.name(i))
                        }
                    }
                }
                legendGroup("Bands at the bottom (activity)") {
                    legendBar(Self.activeColor, "Active")
                    legendBar(Self.sedentaryColor, "Resting")
                    legendBar(Self.exerciseColor, "Exercise ring")
                    if samples.contains(where: \.bridgedActive) {
                        legendBar(Self.bridgedColor, "Filled in")
                    }
                }
                // The measurements: count and sampling in the view.
                VStack(alignment: .leading, spacing: 3) {
                    Text("Measurements").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    if let hz = visible.samplingRateHz {
                        Text("\(samples.count) measurements · sampling in view: \(hz, format: .number.precision(.significantDigits(2))) Hz · about 1 measurement per \(Self.interval(1 / hz))")
                    } else {
                        Text("\(samples.count) measurements")
                    }
                }
                .foregroundStyle(.secondary)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 4)
            } label: {
                Label("Legend", systemImage: "info.circle")
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
    /// At most this many visible measurements before the dots are shown.
    static let maxDotsVisible = 120

    /// The measurement closest to a point in time.
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

    /// Merges measurements where the Exercise ring counts into bands (same rules as the motion band).
    static func exerciseStrips(_ samples: [HRSample]) -> [ExerciseStrip] {
        strips(samples) { $0.inExercise }
    }

    /// Merges measurements that match `include` into bands (same rules as the motion band).
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

    /// A small heading with the legend items below it.
    private func legendGroup<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            HStack(spacing: 12) { content() }
        }
    }

    private func legendBar(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            // Coloured box, like the bands at the bottom of the chart.
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

    /// Merges measurements with the same motion context into bands. Unknown context isn't shown. A band extends to the
    /// next measurement (at most an hour), otherwise one minute.
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

    private func legendDot(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            // A line, like the curve in the chart.
            Capsule().fill(color.opacity(0.8)).frame(width: 14, height: 3)
            Text(title)
        }
    }

    /// The measurements around the visible window (a little extra on both sides so you can swipe).
    private func samplesNear(from: Date, length: TimeInterval) -> ArraySlice<HRSample> {
        samples.slice(from: from.addingTimeInterval(-length), to: from.addingTimeInterval(2 * length))
    }

    /// Heart rate values for the y axis; with many measurements only a sample (min/max is close enough).
    static func sampledValues(_ samples: ArraySlice<HRSample>, max: Int = 3000) -> [Double] {
        guard samples.count > max else { return samples.map(\.bpm) }
        let step = samples.count / max + 1
        return stride(from: samples.startIndex, to: samples.endIndex, by: step).map { samples[$0].bpm }
    }

    /// Thins out to at most `maxDrawnPoints` so long periods still draw quickly. Also returns how many measurements
    /// each drawn dot stands for.
    static func thinned<C: RandomAccessCollection>(_ samples: C, max: Int = maxDrawnPoints) -> ([HRSample], Int)
    where C.Element == HRSample, C.Index == Int {
        guard samples.count > max else { return (Array(samples), 1) }
        let step = Int((Double(samples.count) / Double(max)).rounded(.up))
        return (stride(from: samples.startIndex, to: samples.endIndex, by: step).map { samples[$0] }, step)
    }

    /// Zooms in so the time range (with a little room on each side) fills the chart.
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

    /// Y axis: the measurements ± 5 at zoomOut 0, moving linearly toward 0…max heart rate at zoomOut 1. Numbers on the
    /// y axis: the zone limits within the view, plus round numbers (every 10 or 5 bpm) when the span is small enough
    /// for them to fit. Numbers close to a limit are left out.
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
            stat("Avg.", stats.avg); Spacer()
            stat("Max", stats.max)
        }
    }
    private func stat(_ title: LocalizedStringKey, _ value: Int) -> some View {
        VStack {
            Text("\(value)").font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Period picker at the top of Overview.
struct PeriodHeader: View {
    @Binding var interval: DateInterval
    @State private var showPicker = false

    var body: some View {
        HStack {
            Button { interval = Period.shifted(interval, by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            // A clear button: calendar icon + chevron + background, so it's obvious the period can be changed.
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
            .accessibilityHint("Choose period")
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

/// Overview: Heart Minutes at the top, then heart rate and workouts in detail. (Widgets are the simple ones; the app
/// has the details.)
struct OverviewView: View {
    @Environment(HealthManager.self) private var health
    @Binding var interval: DateInterval
    /// Incremented when the app is opened from a widget: scroll up to the minutes chart.
    var showMinutes = 0
    @State private var focus: HeartChart.FocusRequest?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                // Three "windows" (sections) on top of the background: Heart Minutes, heart rate measurements and
                // workouts.
                let stats = HeartStats(health.shownSamples)
                let result = ActiveMinutes(health.minuteSamples, config: health.minutesConfig)
                let total = result.total
                // Until the new period's data has been fetched, the previous period is shown as a whole.
                let shown = health.loadedInterval ?? interval
                let goal = ActiveMinutes.scaledGoal(weekly: Double(health.weeklyGoal), duration: shown.duration)
                Section {
                    PeriodHeader(interval: $interval)
                        .id("top")
                    // Hero: the big heart ring with the period's number.
                    HeroRing(total: total, goal: goal, period: shown)
                        .listRowSeparator(.hidden)
                    if stats != nil {
                        ActiveMinutesChart(
                            result: result,
                            showHeader: false,
                            period: shown.start...shown.end,
                            zones: health.zones,
                            weeklyGoal: Double(health.weeklyGoal),
                            applePoints: health.applePoints,
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
                            Text("Heart rate").font(.headline)
                            StatsRow(stats: stats)
                        }
                        .id("pulsechart")
                        // With pauses, the filled-in measurements are marked so the band at the bottom can show them.
                        HeartChart(samples: ActiveMinutes.bridgingActive(health.shownSamples, config: health.minutesConfig),
                                   zones: health.zones,
                                   period: shown.start...shown.end,
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
            // No large title: the period starts right at the top.
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: interval) { focus = nil }
            .refreshable { await health.loadPeriod(interval) }
        }
    }
}

/// When there is nothing to show.
struct NoDataView: View {
    @Environment(HealthManager.self) private var health

    var body: some View {
        if !health.includeBackground && !health.includeWorkouts {
            ContentUnavailableView("No measurements selected", systemImage: "line.3.horizontal.decrease.circle",
                description: Text("Turn on background measurements or workouts at the top of Settings."))
        } else {
            ContentUnavailableView("No heart rate data", systemImage: "heart.slash",
                description: Text("Make sure Heart Minutes has access in the Health app."))
        }
    }
}

/// Message when "Only when active" filters out many background measurements because they lack Apple Watch's
/// active/resting marking (e.g. from a ring or another app).
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
            Label("Measurements not counted", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.orange)
            Text("\(Int((info.fraction * 100).rounded())) % of your background measurements (from \(sourceText)) have no active/resting marking, so they don’t count with “Only when active”. The marking only comes from Apple Watch.")
                .font(.callout)
            HStack {
                Button("Turn off “Only when active”", action: turnOff)
                    .buttonStyle(.borderedProminent)
                Button("Ignore", action: ignore)
                    .buttonStyle(.bordered)
            }
            .font(.callout)
        }
        .padding(.vertical, 4)
    }
}

/// Menu where you freely pick the period (from/to with date and time).
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
                    DatePicker("From", selection: $start, in: ...Date.now)
                    DatePicker("To", selection: $end, in: start.addingTimeInterval(60)...)
                } footer: {
                    Text("Duration: \(Duration.seconds(end.timeIntervalSince(start)), format: .units(allowed: [.days, .hours, .minutes], width: .wide))")
                }
                Section {
                    quick("Today", Period.day())
                    quick("This week", Period.thisWeek())
                    // The whole month, just like "This week" is the whole week.
                    quick("This month", Calendar.current.dateInterval(of: .month, for: .now) ?? Period.thisWeek())
                    quick("Last 24 hours", DateInterval(start: .now.addingTimeInterval(-86_400), end: .now))
                    quick("Last 7 days", DateInterval(start: .now.addingTimeInterval(-7 * 86_400), end: .now))
                    quick("Last month", DateInterval(
                        start: Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now.addingTimeInterval(-30 * 86_400),
                        end: .now))
                    quick("Last year", DateInterval(
                        start: Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now.addingTimeInterval(-365 * 86_400),
                        end: .now))
                } header: {
                    Text("Quick picks")
                } footer: {
                    Text("Today, this week and this month are fixed periods: reach the goal before the period ends, then you start over.\n\n“Last …” is a rolling window that moves with time. Here it’s about staying above the goal all the time – old minutes drop out as new ones come in.")
                }
            }
            .navigationTitle("Choose period")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: start) { if end <= start { end = start.addingTimeInterval(3600) } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Show") {
                        interval = DateInterval(start: start, end: end)
                        dismiss()
                    }
                    .disabled(end <= start)
                }
            }
        }
    }

    private func quick(_ title: LocalizedStringKey, _ value: DateInterval) -> some View {
        Button(title) { start = value.start; end = value.end }
    }
}
