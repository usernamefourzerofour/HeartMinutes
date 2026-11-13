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

/// Progress as an Activity-style ring along any shape (circle or heart): dark track, gradient, a new lap above the goal
/// (continuing from 12 o'clock), dark edge (full colour only), a white dot at the current position and only the number
/// in the middle.
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
    /// Above this limit the heart's cleft is cut off straight (bevelled join). Higher = a point down into the hollow
    /// (more heart-like), but it can hit the number in the middle.
    var miterLimit: CGFloat = 2

    static var start: Color { Color(red: 0.88, green: 0.02, blue: 0.27) }
    static var end: Color { Color(red: 1.0, green: 0.36, blue: 0.62) }

    /// The colour at `x` (0…1) of the whole way: from light/faint at the start to deep/full where you have reached.
    /// Full colour: light pink → deep red-pink. Tinted watch face: faint → full (opacity).
    private func tone(_ x: Double) -> Color {
        let t = min(max(x, 0), 1)
        if renderingMode == .fullColor {
            // Light pink (1.0 · 0.70 · 0.82) → deep red-pink (0.82 · 0.0 · 0.24)
            return Color(red: 1.0 - 0.18 * t, green: 0.70 - 0.70 * t, blue: 0.82 - 0.58 * t)
        }
        return Self.start.opacity(0.22 + 0.78 * t)
    }

    var body: some View {
        let f = max(fraction, 0)
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lw = size * thickness
            // Where on the current lap the end is – also after the 2nd, 3rd, … lap.
            let laps = f > 1 ? (f - 0.0005).rounded(.down) : 0
            let pos = f > 1 ? min(max(f - laps, 0.001), 0.999) : f
            // A point at the bottom of the heart, but no long arrow into the cleft (miterLimit).
            let style = { (cap: CGLineCap) in
                StrokeStyle(lineWidth: lw, lineCap: cap, lineJoin: .miter, miterLimit: miterLimit)
            }
            ZStack {
                // The track: the same colour but very dark (fainter on a tinted watch face).
                RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit)
                    .fill(Self.start.opacity(renderingMode == .fullColor ? 0.28 : 0.12))
                if f <= 1 {
                    // Gets gradually more intense all the way to where you have reached.
                    // The gradient ends at the angle of the end point, so the end is exactly tone(1) (for a heart
                    // the angle isn't the same as the fraction of the way).
                    let rect = CGRect(x: 0, y: 0, width: geo.size.width - lw, height: geo.size.height - lw)
                    let endAngle = angleFraction(of: max(f, 0.01), in: rect)
                    // At (almost) 100 % the end is back at 12 o'clock, where the angle wraps to 0.
                    let end = f > 0.5 && endAngle < 0.5 ? 1 : endAngle
                    // Full colour: a flat start with the start's round cap painted underneath in the start colour,
                    // and the end drawn as a "head" on top. A round cap is coloured by angle, so near the cleft the
                    // ray from the centre through the end showed as a thin dark wedge in it.
                    let flat = renderingMode == .fullColor && f > 0.02
                    if flat {
                        startCap(lw: lw, colour: tone(0))
                    }
                    shape.trim(from: 0, to: max(f, 0.001))
                        .stroke(sweep(base: 0, endAngle: end), style: style(flat ? .butt : .round))
                        .widgetAccentable()
                    if flat || f > 0.85 {
                        // Close to the goal the end meets the start in the cleft, and the gradient's seam at
                        // 12 o'clock cut straight through the round end. The head covers it.
                        head(at: f, base: 0, endAngle: end, lw: lw)
                    }
                } else {
                    // Above the goal: the whole shape is drawn as ONE closed stroke (no join at 12 o'clock, which gave
                    // a white line on a tinted watch face). The colour is one continuous scale over the whole way: the
                    // new lap tone(k) → tone(1) from 12 o'clock to the end, then the rest of the previous lap (laps − 1
                    // + p)/f → tone(k).
                    let k = laps / f   // how far along the scale the whole laps reach
                    let rect = CGRect(x: 0, y: 0, width: geo.size.width - lw, height: geo.size.height - lw)
                    let p = angleFraction(of: pos, in: rect)
                    let previous = tone((laps - 1 + p) / f)
                    // In full colour the new lap is drawn on top, so up to the end the previous lap only needs the
                    // colour it has right after the end (no seam that could show next to the end).
                    let lap = AngularGradient(stops: renderingMode == .fullColor ? [
                        .init(color: previous, location: 0),
                        .init(color: previous, location: p),
                        .init(color: tone(k), location: 1),
                    ] : [
                        .init(color: tone(k), location: 0),
                        .init(color: tone(1), location: p),
                        .init(color: previous, location: min(p + 0.0001, 1)),
                        .init(color: tone(k), location: 1),
                    ], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
                    RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit)
                        .fill(lap).widgetAccentable()
                    if renderingMode == .fullColor {
                        // Dark edge below the end so the new lap clearly lies on top. On a light background (Home
                        // Screen) it became a visible black ring – a shadow is used instead.
                        if colorScheme == .dark {
                            EndDot(shape: shape, fraction: pos, radius: lw / 2 + 2).fill(.black)
                        }
                        // The new lap on top: the round cleft at the start in the start colour, then a flat-ended
                        // stroke to the end (the head on top rounds it off).
                        startCap(lw: lw, colour: tone(k))
                        shape.trim(from: 0, to: max(pos, 0.001))
                            .stroke(sweep(base: k, endAngle: p), style: style(.butt))
                    }
                    head(at: pos, base: k, endAngle: p, lw: lw)
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

    /// The end of the progress as a "head": the round end, clipped to the ring. It covers the gradient's seam where the
    /// end meets the start. It is filled with the same colours as the stroke below it (`base` at 12 o'clock → tone(1)
    /// at `endAngle`), but with the gradient turned so its seam is on the opposite side: behind the end it blends into
    /// the stroke, past the end it stays tone(1). (A flat colour, a shadow or an extra stroke all made the end look
    /// like a separate piece.)
    private func head(at pos: Double, base: Double, endAngle: Double, lw: CGFloat) -> some View {
        let e = min(max(endAngle, 0.01), 1)
        let colour = { (a: Double) in self.tone(base + (1 - base) * min(max(a / e, 0), 1)) }
        // Locations are relative to the turned start (e − 0.5): the end sits at 0.5, 12 o'clock at 0.5 − e.
        let stops: [Gradient.Stop] = e >= 0.5
            ? [.init(color: colour(e - 0.5), location: 0), .init(color: tone(1), location: 0.5),
               .init(color: tone(1), location: 1)]
            : [.init(color: colour(0), location: 0), .init(color: colour(0), location: 0.5 - e),
               .init(color: tone(1), location: 0.5), .init(color: tone(1), location: 1)]
        return EndDot(shape: shape, fraction: pos, radius: lw / 2)
            .fill(AngularGradient(stops: stops, center: .center,
                                  startAngle: .degrees(-90 + 360 * (e - 0.5)), endAngle: .degrees(270 + 360 * (e - 0.5))))
            .mask(RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit))
            .widgetAccentable()
    }

    /// The colours along the progress: `base` at 12 o'clock → tone(1) at `endAngle`, tone(1) a bit past the end (the
    /// round end) and `base` just before 12 o'clock (the round start in the cleft). The gradient's seam lies halfway
    /// between the end and 12 o'clock, where nothing of the progress is drawn.
    private func sweep(base: Double, endAngle: Double) -> AngularGradient {
        let e = min(max(endAngle, 0.01), 0.999)
        let m = (e + 1) / 2   // the seam
        let colours: [Gradient.Stop] = [
            .init(color: tone(base), location: 0),
            .init(color: tone(base), location: 1 - m),
            .init(color: tone(1), location: 1 - m + e),
            .init(color: tone(1), location: 1),
        ]
        return AngularGradient(stops: colours, center: .center,
                               startAngle: .degrees(-90 + 360 * m), endAngle: .degrees(270 + 360 * m))
    }

    /// The round start in the cleft, in one colour (drawn below the progress, which starts flat).
    private func startCap(lw: CGFloat, colour: Color) -> some View {
        EndDot(shape: shape, fraction: 0, radius: lw / 2).fill(colour)
            .mask(RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit))
    }

    /// The angle (0…1 from 12 o'clock, clockwise) to the point `fraction` along the shape. For a heart it isn't the
    /// same as the fraction of the way, so the colour change must be placed at the right angle.
    private func angleFraction(of fraction: Double, in rect: CGRect) -> Double {
        let path = shape.path(in: rect)
        guard let pt = path.trimmedPath(from: 0, to: max(fraction, 0.001)).currentPoint
        else { return fraction }
        // A gradient on a shape is centred on the path's bounding box, not on the frame.
        let box = path.boundingRect
        let deg = atan2(pt.y - box.midY, pt.x - box.midX) * 180 / .pi + 90
        return (deg < 0 ? deg + 360 : deg) / 360
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
