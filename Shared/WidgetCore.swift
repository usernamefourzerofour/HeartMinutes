// Fælles for komplikationen på Apple Watch og widgets på iPhone.
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
        // Ur-appen opdaterer data og genindlæser; kig selv igen om 30 min (og ved ugeskift).
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func entry() -> HeartMinutesEntry {
        let data = (ComplicationStore.load() ?? ComplicationData(minutes: 0, goal: 150, updated: .now)).current()
        return HeartMinutesEntry(date: .now, data: data)
    }
}

/// Hvad der står i midten af hjertet (rund komplikation / låseskærm).
enum CenterValue { case percent, minutes }

/// Små widgets til urskive og låseskærm (rund, rektangulær, linje – og hjørne på uret).
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
            // Kort tekst øverst og en lille kurve over perioden – siger mere end det runde widget.
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "heart.fill").font(.caption2).widgetAccentable()
                    // Minutter skrives som antal / mål, fx "207/150 min".
                    Text(center == .percent ? "\(d.percent) %" : "\(minutesText)/\(Int(d.goal.rounded())) min").font(.headline)
                    Text(center == .percent ? "\(minutesText)/\(Int(d.goal.rounded())) min" : "\(d.percent) %")
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
                // iPhone-låseskærm: et udstanset tal viser baggrundsbilledet igennem og drukner.
                // Her dæmpes hjertet i stedet, og tallet står massivt hvidt ovenpå.
                ZStack {
                    AccessoryWidgetBackground()
                    // Svagt hjerte (også når det er fyldt), så det hvide tal altid står tydeligt.
                    ZStack {
                        HeartShape().fill(.white.opacity(0.18))
                        SweepShape(fraction: d.fraction).fill(.white.opacity(0.38)).clipShape(HeartShape())
                    }
                    .padding(2)
                    // Tallet holdes helt inde i hjertets bredeste del (øverst-midt), aldrig ud over kanten.
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

    /// Ur og farvevisning: tallet "stanses ud" af hjertet.
    private var heartWithKnockout: some View {
            ZStack {
                AccessoryWidgetBackground()
                // Tallet "stanses ud" af hjertet, så det kan læses i alle visninger – også når
                // uret er i dvale (dæmpet/ensfarvet), hvor hvid tekst på hjertet ellers forsvinder.
                ZStack {
                    HeartProgress(fraction: d.fraction, color: .pink)
                    // Stort tal (uden "min"), så det kan læses på urskiven – også i dvale.
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

/// Traditionel ring-komplikation (Apple-stil): en ring, der fyldes mod målet, med tallet i midten.
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
            // En rigtig ring til venstre og tallene til højre (ikke en streg).
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
                    Text(center == .percent ? "\(d.percent) %" : "\(Int(d.minutes.rounded()))/\(Int(d.goal.rounded())) min")
                        .font(.headline)
                    Text(center == .percent ? "\(Int(d.minutes.rounded()))/\(Int(d.goal.rounded())) min" : "\(d.percent) %")
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
            // Egen ring i stedet for Gauge, så tallet i midten kan være stort og tydeligt.
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

/// Cirkel, der tegnes fra kl. 12 og med uret (så den kan trimmes som en ring).
struct TopCircle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(rect.width, rect.height) / 2
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()   // ingen samling (hårfin streg) ved kl. 12
        return p
    }
}

/// En prik (cirkel) på formens kant ved `fraction` af vejen rundt.
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

/// Fremskridt som en ring i Aktivitet-stil langs en vilkårlig form (cirkel eller hjerte):
/// mørkt spor, farveforløb, ny omgang over målet (glidende fra kl. 12), mørk kant (kun fuld farve),
/// hvid prik ved nuværende position og kun tallet i midten.
struct ShapeProgressRing<S: Shape>: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let shape: S
    let fraction: Double
    let value: String
    /// Ringens tykkelse som andel af størrelsen.
    var thickness: CGFloat = 0.14
    /// Tallets lodrette placering (0,5 = midten) og bredde som andel af størrelsen.
    var textY: CGFloat = 0.5
    var textWidth: CGFloat = 0.68
    var textSize: CGFloat = 0.36

    static var start: Color { Color(red: 0.88, green: 0.02, blue: 0.27) }
    static var end: Color { Color(red: 1.0, green: 0.36, blue: 0.62) }

    /// Farven ved `x` (0…1) af hele vejen: fra lys/svag i starten til dyb/fuld ved målet du er nået.
    /// Fuld farve: lys pink → dyb rødpink. Tonet urskive: svag → fuld (gennemsigtighed).
    private func tone(_ x: Double) -> Color {
        let t = min(max(x, 0), 1)
        if renderingMode == .fullColor {
            // Lys pink (1,0 · 0,70 · 0,82) → dyb rødpink (0,82 · 0,0 · 0,24)
            return Color(red: 1.0 - 0.18 * t, green: 0.70 - 0.70 * t, blue: 0.82 - 0.58 * t)
        }
        return Self.start.opacity(0.22 + 0.78 * t)
    }

    var body: some View {
        let f = max(fraction, 0)
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lw = size * thickness
            let pos = f > 1 ? min(f - 1, 0.999) : f
            // Spids i hjertets bund, men ingen lang pil ind i kløften (miterLimit).
            let style = { (cap: CGLineCap) in
                StrokeStyle(lineWidth: lw, lineCap: cap, lineJoin: .miter, miterLimit: 2)
            }
            ZStack {
                // Sporet: samme farve, men meget mørkt (svagere på tonet urskive).
                shape.stroke(Self.start.opacity(renderingMode == .fullColor ? 0.28 : 0.12), style: style(.butt))
                if f <= 1 {
                    // Bliver gradvist mere intens hele vejen hen til, hvor du er nået.
                    segment(from: 0, to: f, style: style(.round), colors: [tone(0), tone(1)])
                } else {
                    // Over målet: hele formen tegnes som ÉN lukket streg (ingen samling ved kl. 12, som
                    // gav en hvid streg på tonet urskive). Farven er én sammenhængende skala over hele
                    // forløbet: ny omgang tone(k) → tone(1) fra kl. 12 til enden, derefter resten af
                    // første omgang tone(k·p) → tone(k).
                    let k = 1 / f
                    let rect = CGRect(x: 0, y: 0, width: geo.size.width - lw, height: geo.size.height - lw)
                    let p = angleFraction(of: pos, in: rect)
                    let lap = AngularGradient(stops: [
                        .init(color: tone(k), location: 0),
                        .init(color: tone(1), location: p),
                        .init(color: tone(k * p), location: min(p + 0.0001, 1)),
                        .init(color: tone(k), location: 1),
                    ], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
                    shape.stroke(lap, style: style(.butt)).widgetAccentable()
                    if renderingMode == .fullColor {
                        // Mørk kant under enden, så den nye omgang tydeligt ligger ovenpå.
                        EndDot(shape: shape, fraction: pos, radius: lw / 2 + 2).fill(.black)
                        shape.trim(from: 0, to: pos).stroke(lap, style: style(.butt))
                    }
                    EndDot(shape: shape, fraction: pos, radius: lw / 2).fill(tone(1)).widgetAccentable()
                }
                // Lille hvid prik ved, hvor langt du er nået.
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

    private func segment(from: Double = 0, to t: Double, style: StrokeStyle, colors: [Color]) -> some View {
        shape
            .trim(from: from, to: max(t, 0.001))
            .stroke(AngularGradient(colors: colors, center: .center,
                                    startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * max(t, 0.01))),
                    style: style)
            .widgetAccentable()
    }

    /// Vinklen (0…1 fra kl. 12, med uret) til punktet `fraction` langs formen. For et hjerte er den
    /// ikke den samme som andelen af vejen, så farveskiftet skal lægges ved den rigtige vinkel.
    private func angleFraction(of fraction: Double, in rect: CGRect) -> Double {
        guard let pt = shape.path(in: rect).trimmedPath(from: 0, to: max(fraction, 0.001)).currentPoint
        else { return fraction }
        let deg = atan2(pt.y - rect.midY, pt.x - rect.midX) * 180 / .pi + 90
        return (deg < 0 ? deg + 360 : deg) / 360
    }
}

/// Tyk ring i Aktivitet-stil med procent eller minutter i midten.
struct HeartMinutesBigRingView: View {
    let entry: HeartMinutesEntry
    let center: CenterValue

    var body: some View {
        let d = entry.data
        ShapeProgressRing(shape: TopCircle(), fraction: d.fraction,
                          value: center == .percent ? "\(d.percent)" : "\(Int(d.minutes.rounded()))")
    }
}

/// Hjerte-ring: samme look som den tykke ring, men formet som et hjerte.
struct HeartMinutesHeartRingView: View {
    let entry: HeartMinutesEntry

    var body: some View {
        let d = entry.data
        ShapeProgressRing(shape: HeartOutlineShape(), fraction: d.fraction, value: "\(d.percent)",
                          thickness: 0.13, textY: 0.46, textWidth: 0.46, textSize: 0.3)
    }
}

/// Lille kurve til rektangulære widgets: kumulative minutter over perioden og målet som stiplet linje.
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
                AreaMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(color.opacity(0.25))
                LineMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
            RuleMark(y: .value("Mål", data.goal))
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
