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
        let period = ComplicationStore.watchPeriod
        let data = (ComplicationStore.load(for: period)
            ?? ComplicationData(minutes: 0, goal: period.goal(weekly: 150), updated: .now)).current(for: period)
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

/// Hele formen som én udfyldt streg, med en rund samling i startpunktet (hjertets kløft).
/// Uden den blev kløften skåret lige af, når hele hjertet tegnes (over målet). Med den ser kløften
/// ud som under målet, hvor stregens runde start ligger der. Én samlet figur (union), så der ikke
/// opstår en mørkere plet på tonet urskive, hvor to lag overlapper.
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

/// Den nye omgang over målet som ÉN figur: stregen fra start til `to` plus den runde kløft ved
/// start (samme rundede start som `RoundStartStroke`).
struct NewLapStroke<S: Shape>: Shape {
    let shape: S
    let to: Double
    let lineWidth: CGFloat
    let miterLimit: CGFloat

    func path(in rect: CGRect) -> Path {
        let full = shape.path(in: rect)
        var result = full.trimmedPath(from: 0, to: max(min(to, 1), 0.001))
            .strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .butt, lineJoin: .miter, miterLimit: miterLimit))
        if let start = full.trimmedPath(from: 0, to: 0.0001).currentPoint, start.x.isFinite, start.y.isFinite {
            let r = lineWidth / 2
            result = result.union(Path(ellipseIn: CGRect(x: start.x - r, y: start.y - r, width: 2 * r, height: 2 * r)))
        }
        return result
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
    @Environment(\.colorScheme) private var colorScheme
    let shape: S
    let fraction: Double
    let value: String
    /// Ringens tykkelse som andel af størrelsen.
    var thickness: CGFloat = 0.14
    /// Tallets lodrette placering (0,5 = midten) og bredde som andel af størrelsen.
    var textY: CGFloat = 0.5
    var textWidth: CGFloat = 0.68
    var textSize: CGFloat = 0.36
    /// Over denne grænse bliver hjertets kløft skåret lige af (skrå samling). Højere = spids
    /// nedad i hullet (mere hjerte-agtigt), men den kan ramme tallet i midten.
    var miterLimit: CGFloat = 2

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
            // Hvor på den nuværende omgang enden er – også efter 2., 3., … omgang.
            let laps = f > 1 ? (f - 0.0005).rounded(.down) : 0
            let pos = f > 1 ? min(max(f - laps, 0.001), 0.999) : f
            // Spids i hjertets bund, men ingen lang pil ind i kløften (miterLimit).
            let style = { (cap: CGLineCap) in
                StrokeStyle(lineWidth: lw, lineCap: cap, lineJoin: .miter, miterLimit: miterLimit)
            }
            ZStack {
                // Sporet: samme farve, men meget mørkt (svagere på tonet urskive).
                RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit)
                    .fill(Self.start.opacity(renderingMode == .fullColor ? 0.28 : 0.12))
                if f <= 1 {
                    // Bliver gradvist mere intens hele vejen hen til, hvor du er nået.
                    segment(from: 0, to: f, style: style(.round), colors: [tone(0), tone(1)])
                } else {
                    // Over målet: hele formen tegnes som ÉN lukket streg (ingen samling ved kl. 12, som
                    // gav en hvid streg på tonet urskive). Farven er én sammenhængende skala over hele
                    // forløbet: ny omgang tone(k) → tone(1) fra kl. 12 til enden, derefter resten af
                    // omgangen før (laps − 1 + p)/f → tone(k).
                    let k = laps / f   // hvor langt på skalaen de hele omgange når
                    let rect = CGRect(x: 0, y: 0, width: geo.size.width - lw, height: geo.size.height - lw)
                    let p = angleFraction(of: pos, in: rect)
                    let lap = AngularGradient(stops: [
                        .init(color: tone(k), location: 0),
                        .init(color: tone(1), location: p),
                        .init(color: tone((laps - 1 + p) / f), location: min(p + 0.0001, 1)),
                        .init(color: tone(k), location: 1),
                    ], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
                    RoundStartStroke(shape: shape, lineWidth: lw, miterLimit: miterLimit)
                        .fill(lap).widgetAccentable()
                    if renderingMode == .fullColor {
                        // Mørk kant under enden, så den nye omgang tydeligt ligger ovenpå. På lys baggrund
                        // (hjemmeskærm) blev den en synlig sort ring – der bruges en skygge i stedet.
                        if colorScheme == .dark {
                            EndDot(shape: shape, fraction: pos, radius: lw / 2 + 2).fill(.black)
                        }
                        // Den nye omgang ovenpå – inkl. den runde kløft ved start, så farveskiftet til
                        // omgangen før (ved enden) ikke skærer gennem kløften, når enden er tæt på den.
                        let newLap = AngularGradient(stops: [
                            .init(color: tone(k), location: 0),
                            .init(color: tone(1), location: p),
                            .init(color: tone(k), location: min(p + 0.0001, 1)),
                            .init(color: tone(k), location: 1),
                        ], center: .center, startAngle: .degrees(-90), endAngle: .degrees(270))
                        NewLapStroke(shape: shape, to: pos, lineWidth: lw, miterLimit: miterLimit)
                            .fill(newLap)
                    }
                    EndDot(shape: shape, fraction: pos, radius: lw / 2).fill(tone(1))
                        .shadow(color: renderingMode == .fullColor && colorScheme != .dark
                                ? .black.opacity(0.35) : .clear, radius: lw * 0.15)
                        .widgetAccentable()
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
            // Lidt mindre end hele feltet, så yderkanten ikke skæres af i urskivens hjørner.
            .scaleEffect(0.95)
    }
}

/// Hjerte-ring: samme look som den tykke ring, men formet som et hjerte.
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
