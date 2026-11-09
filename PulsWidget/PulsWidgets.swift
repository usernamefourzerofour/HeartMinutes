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

/// Hjertet ved tallet på hjemmeskærmen: det fyldte hjerte eller hjerte-ringen fra uret.
enum HomeStyle: String, AppEnum {
    case filled, ring

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hjerte")
    static let caseDisplayRepresentations: [HomeStyle: DisplayRepresentation] = [
        .filled: "Fyldt",
        .ring: "Ring",
    ]
}

/// Hjerte-ikonet ved tallet (fyldt eller ring).
struct HomeHeartIcon: View {
    let entry: ConfigEntry

    var body: some View {
        if entry.homeStyle == .ring {
            ShapeProgressRing(shape: HeartOutlineShape(), fraction: entry.data.fraction, value: "",
                              thickness: 0.17)
        } else {
            HeartProgress(fraction: entry.data.fraction, color: .pink)
        }
    }
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

    @Parameter(title: "Hjerte", default: .filled)
    var homeStyle: HomeStyle

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
    var homeStyle: HomeStyle = .filled
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
                           display: c.display, style: c.style,
                           homeStyle: (c as? HeartMinutesHomeConfig)?.homeStyle ?? .filled)
    }
}

// MARK: - Visning

/// Kurve over perioden: kumulative Heart Minutes med målet som stiplet linje.
struct PeriodChart: View {
    let entry: ConfigEntry
    /// Lille widget: mindre tekst på aksen og ved mållinjen.
    var compact = false

    /// Lodrette skillelinjer mellem dage/datoer – tydelige, men stadig diskrete.
    private var gridStyle: Color { .gray.opacity(0.45) }

    var body: some View {
        let data = entry.data
        let domain = entry.period.chartDomain(now: data.updated)
        // Kurven fortsætter vandret til nu, også gennem dage uden nye minutter.
        let points = ComplicationData.spanning(data.points ?? [], from: domain.lowerBound,
                                              to: min(entry.date, domain.upperBound))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(.pink.opacity(0.25))
                LineMark(x: .value("Tid", p.t), y: .value("Minutter", p.v))
                    .foregroundStyle(.pink)
            }
            RuleMark(y: .value("Mål", data.goal))
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .annotation(position: .top, alignment: .leading, spacing: 1) {
                    // Lille widget: målet står allerede i teksten ovenover (labelen overlappede den).
                    if !compact {
                        Text("Mål \(Int(data.goal.rounded())) min")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
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

/// Hjertet med tallet – venstre side af hjemmeskærm-widgetten.
struct HeartSummary: View {
    let entry: ConfigEntry

    var body: some View {
        let d = entry.data
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                HomeHeartIcon(entry: entry)
                    .frame(width: 58, height: 50)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(entry.display == .percent ? "\(d.percent) %" : "\(Int(d.minutes.rounded()))")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                if entry.display == .minutes {
                    Text("min")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            Text(entry.display == .percent
                 ? "\(Int(d.minutes.rounded())) af \(Int(d.goal.rounded())) min"
                 : "af \(Int(d.goal.rounded())) min · \(d.percent) %")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(entry.period.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.pink)
                .lineLimit(1)
        }
    }
}

/// Lille hjemmeskærm-widget: hjerte og tal på én linje, så der er plads til kurven nedenunder.
struct SmallHomeView: View {
    let entry: ConfigEntry

    var body: some View {
        let d = entry.data
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                HomeHeartIcon(entry: entry)
                    .frame(width: 30, height: 26)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(entry.display == .percent ? "\(d.percent) %" : "\(Int(d.minutes.rounded()))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    if entry.display == .minutes {
                        Text("min")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            }
            Text(entry.display == .percent
                 ? "\(Int(d.minutes.rounded())) af \(Int(d.goal.rounded())) min"
                 : "af \(Int(d.goal.rounded())) min · \(d.percent) %")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            PeriodChart(entry: entry, compact: true)
                .padding(.vertical, 2)
            Text(entry.period.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.pink)
                .lineLimit(1)
        }
    }
}

struct HomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ConfigEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallHomeView(entry: entry)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(spacing: 14) {
                HeartSummary(entry: entry).frame(width: 110, alignment: .leading)
                PeriodChart(entry: entry)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .bottom) {
                    HeartSummary(entry: entry)
                    Spacer()
                    Text("Heart Minutes").font(.headline).foregroundStyle(.pink)
                }
                .frame(height: 120)
                PeriodChart(entry: entry)
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
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes")
        .description("Heart Minutes mod dit mål – vælg periode og minutter eller procent. Hjertet kan være fyldt eller en ring.")
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
