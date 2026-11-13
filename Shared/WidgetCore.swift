// Shared by the Apple Watch complication and the iPhone widgets.
import SwiftUI
import WidgetKit
import Charts

struct HeartMinutesEntry: TimelineEntry {
    let date: Date
    let data: ComplicationData
}

struct HeartMinutesProvider: TimelineProvider {
    func placeholder(in context: Context) -> HeartMinutesEntry {
        HeartMinutesEntry(date: .now, data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HeartMinutesEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeartMinutesEntry>) -> Void) {
        // The watch app updates the data and reloads; check again in 30 min (and when the week changes).
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func entry() -> HeartMinutesEntry {
        let period = ComplicationStore.watchPeriod
        let data = (ComplicationStore.load(for: period)
            ?? ComplicationData(minutes: 0, goal: period.goal(weekly: 150), updated: .now)).current(for: period)
        return HeartMinutesEntry(date: .now, data: data)
    }
}

/// What is shown in the middle of the heart (round complication / Lock Screen).
enum CenterValue { case percent, minutes }

/// Small widgets for the watch face and Lock Screen (round, rectangular, inline – and corner on the watch).
struct HeartMinutesView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: HeartMinutesEntry
    let center: CenterValue
    var period: SummaryPeriod = .thisWeek

    private var d: ComplicationData { entry.data }
    private var minutesText: String { "\(Int(d.minutes.rounded()))" }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // Short text at the top and a small curve over the period – says more than the round widget.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "heart.fill").font(.caption2).widgetAccentable()
                    // Minutes are written as count / goal, e.g. "207/150 min".
                    (center == .percent ? Text("\(d.percent) %") : Text("\(minutesText)/\(Int(d.goal.rounded())) min")).font(.headline)
                    (center == .percent ? Text("\(minutesText)/\(Int(d.goal.rounded())) min") : Text("\(d.percent) %"))
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .lineLimit(1)
                MiniChart(data: d, period: period)
            }
        case .accessoryInline:
            Text("♥ \(minutesText)/\(Int(d.goal)) min")
        #if os(watchOS)
        case .accessoryCorner:
            Text(center == .percent ? "\(d.percent)%" : minutesText)
                .font(.title3.bold())
                .widgetLabel {
                    Gauge(value: min(d.fraction, 1)) { Text("Heart Minutes") }
                        .tint(.pink)
                }
        #endif
        default:
            if renderingMode == .vibrant {
                // iPhone Lock Screen: a knocked-out number shows the wallpaper through and gets lost. Here the heart is
                // dimmed instead and the number sits solid white on top.
                ZStack {
                    AccessoryWidgetBackground()
                    // Faint heart (also when filled) so the white number always stands out.
                    ZStack {
                        HeartShape().fill(.white.opacity(0.18))
                        SweepShape(fraction: d.fraction).fill(.white.opacity(0.38)).clipShape(HeartShape())
                    }
                    .padding(2)
                    // The number is kept fully inside the widest part of the heart (top middle), never past the edge.
                    GeometryReader { geo in
                        Text(center == .percent ? "\(d.percent)%" : minutesText)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .frame(width: geo.size.width * 0.56)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
                    }
                }
            } else {
                heartWithKnockout
            }
        }
    }

    /// Watch and full colour: the number is "knocked out" of the heart.
    private var heartWithKnockout: some View {
            ZStack {
                AccessoryWidgetBackground()
                // The number is "knocked out" of the heart so it can be read in every mode – also when the watch is
                // dimmed (low power/monochrome), where white text on the heart would otherwise disappear.
                ZStack {
                    HeartProgress(fraction: d.fraction, color: .pink)
                    // Big number (without "min") so it can be read on the watch face – also when dimmed.
                    Text(center == .percent ? "\(d.percent)%" : minutesText)
                        .font(.system(size: center == .percent ? 19 : 23, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .offset(y: -2)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
                .widgetAccentable()
                .padding(2)
            }
    }
}

/// Traditional ring complication (Apple style): a ring that fills toward the goal, with the number in the middle.
struct HeartMinutesRingView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HeartMinutesEntry
    let center: CenterValue
    var period: SummaryPeriod = .thisWeek

    private var d: ComplicationData { entry.data }
    private var value: String { center == .percent ? "\(d.percent)%" : "\(Int(d.minutes.rounded()))" }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            // A real ring on the left and the numbers on the right (not a line).
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.primary.opacity(0.25), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(d.fraction, 1))
                        .stroke(.pink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()
                    Image(systemName: "heart.fill").font(.system(size: 13)).widgetAccentable()
                }
                .padding(2.5)
                .aspectRatio(1, contentMode: .fit)
                VStack(alignment: .leading, spacing: 0) {
                    (center == .percent ? Text("\(d.percent) %") : Text("\(Int(d.minutes.rounded()))/\(Int(d.goal.rounded())) min"))
                        .font(.headline)
                    (center == .percent ? Text("\(Int(d.minutes.rounded()))/\(Int(d.goal.rounded())) min") : Text("\(d.percent) %"))
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(period.title).font(.caption2).foregroundStyle(.secondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Text("♥ \(Int(d.minutes.rounded()))/\(Int(d.goal.rounded())) min")
        #if os(watchOS)
        case .accessoryCorner:
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundStyle(.pink)
                .widgetLabel {
                    Gauge(value: min(d.fraction, 1)) { Text("Heart Minutes") } currentValueLabel: { Text(value) }
                        .tint(.pink)
                }
        #endif
        default:
            // Own ring instead of Gauge, so the number in the middle can be big and clear.
            ZStack {
                AccessoryWidgetBackground()
                Circle()
                    .stroke(.pink.opacity(0.3), lineWidth: 4)
                    .padding(3)
                Circle()
                    .trim(from: 0, to: min(d.fraction, 1))
                    .stroke(.pink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
                    .widgetAccentable()
                Text(value)
                    .font(.system(size: center == .percent ? 19 : 23, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
            }
        }
    }
}

/// Circle drawn from 12 o'clock, clockwise (so it can be trimmed like a ring).
struct TopCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()   // no join (hairline) at 12 o'clock
        return p
    }
}

/// The whole shape as one filled stroke, with a round join at the start point (the heart's cleft). Without it the cleft
/// was cut off straight when the whole heart is drawn (above the goal). With it the cleft looks like below the goal,
/// where the stroke's round start sits. One combined shape (union), so no darker spot appears on a tinted watch face
/// where two layers overlap.
struct RoundStartStroke<S: Shape>: Shape {
    let shape: S
    let lineWidth: CGFloat
    let miterLimit: CGFloat

    func path(in rect: CGRect) -> Path {
        let full = shape.path(in: rect)
        let stroked = full.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .butt,
                                                   lineJoin: .miter, miterLimit: miterLimit))
        guard let start = full.trimmedPath(from: 0, to: 0.0001).currentPoint else { return stroked }
        let r = lineWidth / 2
        return stroked.union(Path(ellipseIn: CGRect(x: start.x - r, y: start.y - r, width: 2 * r, height: 2 * r)))
    }
}

/// A dot (circle) on the shape's edge at `fraction` of the way round.
struct EndDot<S: Shape>: Shape {
    let shape: S
    let fraction: Double
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let full = shape.path(in: rect)
        let pt = fraction <= 0.0005
            ? (full.trimmedPath(from: 0, to: 0.001).currentPoint ?? .zero)
            : (full.trimmedPath(from: 0, to: min(fraction, 1)).currentPoint ?? .zero)
        return Path(ellipseIn: CGRect(x: pt.x - radius, y: pt.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Progress as an Activity-style ring along any shape (circle or heart): dark track, a colour scale along the stroke, a
/// new lap above the goal (continuing from 12 o'clock), dark edge (dark mode only), a white dot at the current position
/// and only the number in the middle.
///
/// The colour follows the way along the shape, not the angle: the progress is drawn as many short pieces, each in its
/// own colour. (An angular gradient gave seams on a heart, where the angle and the way along it don't match.)
struct ShapeProgressRing<S: Shape>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    let shape: S
    let fraction: Double
    let value: String
    /// The ring's thickness as a fraction of the size.
    var thickness: CGFloat = 0.14
    /// The number's vertical position (0.5 = middle) and width as a fraction of the size.
    var textY: CGFloat = 0.5
    var textWidth: CGFloat = 0.68
    var textSize: CGFloat = 0.36
    /// For shapes with corners (only the track uses it; the heart has rounded corners).
    var miterLimit: CGFloat = 2

    static var start: Color { Color(red: 0.88, green: 0.02, blue: 0.27) }
    static var end: Color { Color(red: 1.0, green: 0.36, blue: 0.62) }

    /// Pieces per lap: enough that the steps in colour can't be seen.
    private static var piecesPerLap: Double { 160 }

    /// The colour at `x` (0…1) of the whole way: from light at the start to deep where you have reached.
    /// Full colour: light pink (1.0 · 0.70 · 0.82) → deep red-pink (0.82 · 0.0 · 0.24). Other modes: a grey level that
    /// becomes the opacity (faint → full) through a luminance mask, so overlapping pieces don't show.
    private func tone(_ x: Double) -> Color {
        let t = min(max(x, 0), 1)
        if renderingMode == .fullColor {
            return Color(red: 1.0 - 0.18 * t, green: 0.70 - 0.70 * t, blue: 0.82 - 0.58 * t)
        }
        return Color(white: 0.22 + 0.78 * t)
    }

    var body: some View {
        let f = max(fraction, 0)
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lw = size * thickness
            // Where on the current lap the end is – also after the 2nd, 3rd, … lap.
            let laps = f > 1 ? (f - 0.0005).rounded(.down) : 0
            let pos = f > 1 ? min(max(f - laps, 0.001), 0.999) : f
            ZStack {
                // The track: the same colour but very dark (fainter on a tinted watch face).
                RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit)
                    .fill(Self.start.opacity(renderingMode == .fullColor ? 0.28 : 0.12))
                if f > 0 {
                    if renderingMode == .fullColor {
                        progress(f: f, laps: laps, pos: pos, lw: lw)
                    } else {
                        // Tinted: the grey levels become the opacity of one colour.
                        Rectangle().fill(Self.start)
                            .mask(progress(f: f, laps: laps, pos: pos, lw: lw).luminanceToAlpha())
                            .widgetAccentable()
                    }
                }
                // Small white dot where you have reached.
                EndDot(shape: shape, fraction: pos, radius: lw * 0.19).fill(.white)
            }
            .padding(lw / 2)
            .overlay {
                Text(value)
                    .font(.system(size: size * textSize, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .frame(width: size * textWidth)
                    .position(x: geo.size.width / 2, y: geo.size.height * textY)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// The progress itself. Below the goal: tone(0) at the start → tone(1) at the end. Above the goal one continuous
    /// scale over the whole way: the rest of the previous lap, then the new lap on top of it from 12 o'clock to the end.
    /// Each part has a round start (in the cleft) and a round end, drawn as circles in the colour there.
    private func progress(f: Double, laps: Double, pos: Double, lw: CGFloat) -> some View {
        let darkEdge = renderingMode == .fullColor && colorScheme == .dark
        return Canvas { context, canvasSize in
            let path = shape.path(in: CGRect(origin: .zero, size: canvasSize))
            let style = StrokeStyle(lineWidth: lw, lineCap: .butt, lineJoin: .round)
            func point(_ u: Double) -> CGPoint? {
                path.trimmedPath(from: 0, to: min(max(u, 0.0001), 1)).currentPoint
            }
            func dot(_ u: Double, radius: CGFloat, _ color: Color) {
                guard let p = point(u) else { return }
                context.fill(Path(ellipseIn: CGRect(x: p.x - radius, y: p.y - radius, width: 2 * radius,
                                                    height: 2 * radius)), with: .color(color))
            }
            /// Short pieces from `u0` to `u1`, each in the colour `color(u)` at its middle. Each piece reaches a little
            /// into the next one, so no hairline shows between them.
            func stroke(from u0: Double, to u1: Double, _ color: (Double) -> Color) {
                let count = max(1, Int(((u1 - u0) * Self.piecesPerLap).rounded(.up)))
                let step = (u1 - u0) / Double(count)
                for n in 0..<count {
                    let a = u0 + step * Double(n)
                    let b = min(a + step * 1.6, u1)
                    context.stroke(path.trimmedPath(from: a, to: b), with: .color(color(a + step / 2)), style: style)
                }
            }
            if f <= 1 {
                dot(0, radius: lw / 2, tone(0))
                stroke(from: 0, to: f) { tone($0 / f) }
                dot(f, radius: lw / 2, tone(1))
            } else {
                stroke(from: pos, to: 1) { tone((laps - 1 + $0) / f) }   // the rest of the previous lap
                // Dark edge below the end so the new lap clearly lies on top (only on a dark background).
                if darkEdge { dot(pos, radius: lw / 2 + 2, .black) }
                dot(0, radius: lw / 2, tone(laps / f))
                stroke(from: 0, to: pos) { tone((laps + $0) / f) }       // the new lap
                dot(pos, radius: lw / 2, tone(1))
            }
        }
    }
}

/// Thick Activity-style ring with percent or minutes in the middle.
struct HeartMinutesBigRingView: View {
    let entry: HeartMinutesEntry
    let center: CenterValue

    var body: some View {
        let d = entry.data
        ShapeProgressRing(shape: TopCircle(), fraction: d.fraction,
                          value: center == .percent ? "\(d.percent)" : "\(Int(d.minutes.rounded()))")
            // Slightly smaller than the whole area so the outer edge isn't cut off in the watch face's corners.
            .scaleEffect(0.95)
    }
}

/// Heart ring: the same look as the thick ring, but shaped like a heart.
struct HeartMinutesHeartRingView: View {
    let entry: HeartMinutesEntry
    var center: CenterValue = .percent

    var body: some View {
        let d = entry.data
        ShapeProgressRing(shape: HeartOutlineShape(), fraction: d.fraction,
                          value: center == .percent ? "\(d.percent)" : "\(Int(d.minutes.rounded()))",
                          thickness: 0.13, textY: 0.46, textWidth: 0.46, textSize: 0.3)
    }
}

/// Small curve for rectangular widgets: cumulative minutes over the period and the goal as a dashed line.
struct MiniChart: View {
    let data: ComplicationData
    let period: SummaryPeriod
    var color: Color = .primary

    var body: some View {
        let domain = period.chartDomain(now: data.updated)
        let points = ComplicationData.spanning(data.points ?? [], from: domain.lowerBound,
                                              to: min(.now, domain.upperBound))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Time", p.t), y: .value("Minutes", p.v))
                    .foregroundStyle(color.opacity(0.25))
                LineMark(x: .value("Time", p.t), y: .value("Minutes", p.v))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            RuleMark(y: .value("Goal", data.goal))
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        .chartXScale(domain: period.chartDomain(now: data.updated))
        .chartYScale(domain: 0...max(data.goal, data.minutes, 1) * 1.05)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .widgetAccentable()
    }
}
