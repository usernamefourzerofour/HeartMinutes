import SwiftUI
import WidgetKit
import Charts
import AppIntents

// MARK: - Indstillinger for widgetten (Rediger widget)

extension SummaryPeriod: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Periode")
    static let caseDisplayRepresentations: [SummaryPeriod: DisplayRepresentation] = [
        .today: "I dag",
        .thisWeek: "Denne uge",
        .thisMonth: "Denne måned",
        .last3Days: "Seneste 3 dage",
        .last7Days: "Seneste 7 dage",
        .last14Days: "Seneste 14 dage",
        .last30Days: "Seneste 30 dage",
    ]
}

/// Om det store tal er minutter eller procent af målet.
enum WidgetDisplay: String, AppEnum {
    case minutes, percent

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Vis")
    static let caseDisplayRepresentations: [WidgetDisplay: DisplayRepresentation] = [
        .minutes: "Minutter",
        .percent: "Procent",
    ]
}

/// Udseende på låseskærmen: hjertet fra app-ikonet eller en traditionel ring.
enum WidgetStyle: String, AppEnum {
    case heart, ring

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Stil")
    static let caseDisplayRepresentations: [WidgetStyle: DisplayRepresentation] = [
        .heart: "Hjerte",
        .ring: "Ring",
    ]
}

/// Fælles for widget-indstillingerne, så samme data/visning kan bruges af begge widgets.
protocol HeartMinutesIntent: WidgetConfigurationIntent {
    var period: SummaryPeriod { get }
    var display: WidgetDisplay { get }
    var style: WidgetStyle { get }
}

/// Hjemmeskærm: periode og minutter/procent.
struct HeartMinutesHomeConfig: HeartMinutesIntent {
    static let title: LocalizedStringResource = "Heart Minutes"
    static let description = IntentDescription("Vælg periode, og om tallet vises i minutter eller procent af målet.")

    @Parameter(title: "Periode", default: .thisWeek)
    var period: SummaryPeriod

    @Parameter(title: "Vis", default: .minutes)
    var display: WidgetDisplay

    var style: WidgetStyle { .heart }
}

/// Låseskærm: som hjemmeskærmen + stil (hjerte eller ring).
struct HeartMinutesLockConfig: HeartMinutesIntent {
    static let title: LocalizedStringResource = "Heart Minutes"
    static let description = IntentDescription("Vælg periode, minutter eller procent, og hjerte eller ring.")

    @Parameter(title: "Periode", default: .thisWeek)
    var period: SummaryPeriod

    @Parameter(title: "Vis", default: .minutes)
    var display: WidgetDisplay

    @Parameter(title: "Stil", default: .heart)
    var style: WidgetStyle
}

// MARK: - Data

struct ConfigEntry: TimelineEntry {
    let date: Date
    let data: ComplicationData
    let period: SummaryPeriod
    let display: WidgetDisplay
    var style: WidgetStyle = .heart
}

struct ConfigProvider<Intent: HeartMinutesIntent>: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ConfigEntry {
        ConfigEntry(date: .now, data: .placeholder, period: .thisWeek, display: .minutes)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> ConfigEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<ConfigEntry> {
        // Appen gemmer nye tal og genindlæser widgets; kig selv igen om 30 min (og ved dags-/ugeskift).
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(30 * 60)))
    }

    private func entry(for c: Intent) -> ConfigEntry {
        let stored = ComplicationStore.load(for: c.period)
            ?? ComplicationData(minutes: 0, goal: c.period.goal(weekly: 150), updated: .now)
        return ConfigEntry(date: .now, data: stored.current(for: c.period), period: c.period,
                           display: c.display, style: c.style)
    }
}

// MARK: - Visning

/// Kurve over perioden: kumulative Heart Minutes med målet som stiplet linje.
struct PeriodChart: View {
    let entry: ConfigEntry
    /// Lille widget: mindre tekst på aksen og ved mållinjen.
    var compact = false

    /// Lodrette skillelinjer mellem dage/datoer – tydelige, men stadig diskrete.
    private var gridStyle: Color { .gray.opacity(0.3) }

    var body: some View {
        let data = entry.data
        let domain = entry.period.chartDomain(now: data.updated)
        // Kurven fortsætter vandret til nu, også gennem dage uden nye minutter.
        let points = ComplicationData.spanning(data.points ?? [], from: domain.lowerBound,
                                              to: min(entry.date, domain.upperBound))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(Brand.area())
                LineMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(Brand.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            RuleMark(y: .value("Mål", data.goal))
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                // Lille widget: under stregen, så den ikke rammer teksten ovenover.
                .annotation(position: compact ? .bottom : .top, alignment: .leading, spacing: 1) {
                    Text("Mål \(Int(data.goal.rounded())) min")
                        .font(.system(size: compact ? 8 : 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...max(data.goal, data.minutes, 1) * 1.1)
        .chartXAxis {
            if entry.period == .today {
                AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(gridStyle)
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.system(size: compact ? 8 : 10))
                }
            } else if entry.period.goalDays() <= 7 {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(gridStyle)
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .font(.system(size: compact ? 8 : 10))
                }
            } else {
                // Lange perioder: datoer med faste mellemrum (hver 3. dag op til 14 dage, ellers hver uge; færre på lille widget).
                AxisMarks(values: Self.dateTicks(in: domain, stepDays: entry.period.goalDays() <= 14 ? (compact ? 5 : 3) : (compact ? 10 : 7))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(gridStyle)
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                        .font(.system(size: compact ? 8 : 10))
                }
            }
        }
        .chartYAxis(.hidden)
    }

    /// Midnatsdatoer fra dagen efter periodens start og frem, med `stepDays` imellem.
    static func dateTicks(in domain: ClosedRange<Date>, stepDays: Int,
                          calendar: Calendar = .current) -> [Date] {
        var ticks: [Date] = []
        guard var d = calendar.date(byAdding: .day, value: 1,
                                    to: calendar.startOfDay(for: domain.lowerBound)) else { return [] }
        while d < domain.upperBound {
            ticks.append(d)
            guard let next = calendar.date(byAdding: .day, value: stepDays, to: d) else { break }
            d = next
        }
        return ticks
    }
}

/// Hjerte-ringen med tallet i midten – widgettens ansigt (samme som komplikationen på uret).
struct WidgetRing: View {
    let entry: ConfigEntry

    var body: some View {
        let d = entry.data
        ShapeProgressRing(shape: HeartOutlineShape(), fraction: d.fraction,
                          value: entry.display == .percent ? "\(d.percent)" : "\(Int(d.minutes.rounded()))",
                          thickness: 0.13, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .aspectRatio(1, contentMode: .fit)
    }
}

/// De to små linjer under ringen: enhed/mål og perioden.
struct WidgetCaption: View {
    let entry: ConfigEntry
    var alignment: HorizontalAlignment = .center
    /// Teksten på flere korte linjer (lille widget, ved siden af ringen).
    var stacked = false

    var body: some View {
        let d = entry.data
        VStack(alignment: alignment, spacing: 1) {
            if stacked && entry.display == .percent {
                // Lille widget: smal plads ved siden af ringen, så minutterne får deres egen linje.
                Text("\(Int(d.minutes.rounded())) min")
                    .font(.caption2.weight(.semibold))
                Text("af \(Int(d.goal.rounded())) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                (entry.display == .percent
                 ? Text("% · \(Int(d.minutes.rounded())) af \(Int(d.goal.rounded())) min")
                 : Text("af \(Int(d.goal.rounded())) min"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(entry.period.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Brand.accent)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// Svag farveovergang bag hjemmeskærm-widgets: varm hvid → sart rosa (mørk: dyb rødbrun → sort).
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(colors: colorScheme == .dark
                       ? [Color(red: 0.15, green: 0.07, blue: 0.09), .black]
                       : [.white, Color(red: 1.0, green: 0.93, blue: 0.94)],
                       startPoint: .top, endPoint: .bottom)
    }
}

struct HomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConfigEntry

    var body: some View {
        let d = entry.data
        switch family {
        case .systemSmall:
            // Ringen med teksten ved siden af og grafen under.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    WidgetRing(entry: entry)
                        .frame(width: 62, height: 62)
                    WidgetCaption(entry: entry, alignment: .leading, stacked: true)
                    Spacer(minLength: 0)
                }
                PeriodChart(entry: entry, compact: true)
            }
        case .systemMedium:
            HStack(spacing: 14) {
                VStack(spacing: 4) {
                    WidgetRing(entry: entry)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    WidgetCaption(entry: entry)
                }
                .frame(width: 112)
                PeriodChart(entry: entry)
            }
        default:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    WidgetRing(entry: entry)
                        .frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Heart Minutes")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Brand.accent)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(d.minutes.rounded()))")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                            Text("min")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        Text("af \(Int(d.goal.rounded())) min · \(d.percent) %")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.period.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                PeriodChart(entry: entry)
                // Fordelingen på pulszoner (ikke ved ældre data).
                if let zones = d.zones, !zones.isEmpty {
                    ZoneBar(slices: zones)
                }
            }
        }
    }
}

/// Låseskærm: den lille runde er de samme to ringe som på uret (ring eller hjerte);
/// rektangulær og linje er uændrede.
struct LockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConfigEntry

    var body: some View {
        let e = HeartMinutesEntry(date: entry.date, data: entry.data)
        let center: CenterValue = entry.display == .percent ? .percent : .minutes
        switch (family, entry.style) {
        case (.accessoryCircular, .ring): HeartMinutesBigRingView(entry: e, center: center)
        case (.accessoryCircular, .heart): HeartMinutesHeartRingView(entry: e, center: center)
        case (_, .ring): HeartMinutesRingView(entry: e, center: center, period: entry.period)
        case (_, .heart): HeartMinutesView(entry: e, center: center, period: entry.period)
        }
    }
}

// MARK: - Widgets

/// Hjemmeskærm (lille, mellem med graf, stor med graf) og StandBy.
struct HeartMinutesHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HeartMinutesHome", intent: HeartMinutesHomeConfig.self,
                               provider: ConfigProvider<HeartMinutesHomeConfig>()) { entry in
            HomeWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes")
        .description("Heart Minutes mod dit mål – vælg periode og minutter eller procent.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Låseskærm: rundt hjerte, rektangulær og linje.
struct HeartMinutesLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HeartMinutesLock", intent: HeartMinutesLockConfig.self,
                               provider: ConfigProvider<HeartMinutesLockConfig>()) { entry in
            LockWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes")
        .description("Heart Minutes på låseskærmen – vælg periode, minutter eller procent, og hjerte eller ring.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct PulsWidgets: WidgetBundle {
    var body: some Widget {
        HeartMinutesHomeWidget()
        HeartMinutesLockWidget()
    }
}
