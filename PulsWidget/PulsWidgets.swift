import SwiftUI
import WidgetKit
import Charts
import AppIntents

// MARK: - Widget settings (Edit Widget)

extension SummaryPeriod: AppEnum {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Period")
    static let caseDisplayRepresentations: [SummaryPeriod: DisplayRepresentation] = [
        .today: "Today",
        .thisWeek: "This week",
        .thisMonth: "This month",
        .last3Days: "Last 3 days",
        .last7Days: "Last 7 days",
        .last14Days: "Last 14 days",
        .last30Days: "Last 30 days",
    ]
}

/// Whether the big number is minutes or percent of the goal.
enum WidgetDisplay: String, AppEnum {
    case minutes, percent

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Show")
    static let caseDisplayRepresentations: [WidgetDisplay: DisplayRepresentation] = [
        .minutes: "Minutes",
        .percent: "Percent",
    ]
}

/// Look on the Lock Screen: the heart from the app icon or a traditional ring.
enum WidgetStyle: String, AppEnum {
    case heart, ring

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Style")
    static let caseDisplayRepresentations: [WidgetStyle: DisplayRepresentation] = [
        .heart: "Heart",
        .ring: "Ring",
    ]
}

/// Shared by the widget settings so the same data/view can be used by both widgets.
protocol HeartMinutesIntent: WidgetConfigurationIntent {
    var period: SummaryPeriod { get }
    var display: WidgetDisplay { get }
    var style: WidgetStyle { get }
}

/// Home Screen: period and minutes/percent.
struct HeartMinutesHomeConfig: HeartMinutesIntent {
    static let title: LocalizedStringResource = "Heart Minutes"
    static let description = IntentDescription("Choose the period and whether the number is shown in minutes or percent of the goal.")

    @Parameter(title: "Period", default: .thisWeek)
    var period: SummaryPeriod

    @Parameter(title: "Show", default: .minutes)
    var display: WidgetDisplay

    var style: WidgetStyle { .heart }
}

/// Lock Screen: like the Home Screen + style (heart or ring).
struct HeartMinutesLockConfig: HeartMinutesIntent {
    static let title: LocalizedStringResource = "Heart Minutes"
    static let description = IntentDescription("Choose the period, minutes or percent, and heart or ring.")

    @Parameter(title: "Period", default: .thisWeek)
    var period: SummaryPeriod

    @Parameter(title: "Show", default: .minutes)
    var display: WidgetDisplay

    @Parameter(title: "Style", default: .heart)
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
        // The app saves new numbers and reloads widgets; check again in 30 min (and when the day/week changes).
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(30 * 60)))
    }

    private func entry(for c: Intent) -> ConfigEntry {
        let stored = ComplicationStore.load(for: c.period)
            ?? ComplicationData(minutes: 0, goal: c.period.goal(weekly: 150), updated: .now)
        return ConfigEntry(date: .now, data: stored.current(for: c.period), period: c.period,
                           display: c.display, style: c.style)
    }
}

// MARK: - Views

/// Curve over the period: cumulative Heart Minutes with the goal as a dashed line.
struct PeriodChart: View {
    let entry: ConfigEntry
    /// Small widget: smaller text on the axis and at the goal line.
    var compact = false

    /// Vertical dividers between days/dates – clear but still subtle.
    private var gridStyle: Color { .gray.opacity(0.3) }

    var body: some View {
        let data = entry.data
        let domain = entry.period.chartDomain(now: data.updated)
        // The curve continues horizontally to now, also through days without new minutes.
        let points = ComplicationData.spanning(data.points ?? [], from: domain.lowerBound,
                                              to: min(entry.date, domain.upperBound))
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Time", p.t), y: .value("Minutes", p.v))
                    .foregroundStyle(Brand.area())
                LineMark(x: .value("Time", p.t), y: .value("Minutes", p.v))
                    .foregroundStyle(Brand.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            RuleMark(y: .value("Goal", data.goal))
                .foregroundStyle(Color.gray)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                // Small widget: below the line so it doesn't hit the text above.
                .annotation(position: compact ? .bottom : .top, alignment: .leading, spacing: 1) {
                    Text("Goal \(Int(data.goal.rounded())) min")
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
                // Long periods: dates at fixed intervals (every 3 days up to 14 days, otherwise every week; fewer on
                // the small widget).
                AxisMarks(values: Self.dateTicks(in: domain, stepDays: entry.period.goalDays() <= 14 ? (compact ? 5 : 3) : (compact ? 10 : 7))) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(gridStyle)
                    AxisValueLabel(format: .dateTime.day().month(.defaultDigits))
                        .font(.system(size: compact ? 8 : 10))
                }
            }
        }
        .chartYAxis(.hidden)
    }

    /// Midnight dates from the day after the period's start onward, with `stepDays` between them.
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

/// The heart ring with the number in the middle – the face of the widget (the same as the complication on the watch).
struct WidgetRing: View {
    let entry: ConfigEntry

    var body: some View {
        let d = entry.data
        ShapeProgressRing(shape: HeartOutlineShape(), fraction: d.fraction,
                          value: entry.display == .percent ? "\(d.percent)" : "\(Int(d.minutes.rounded()))",
                          thickness: 0.12, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .aspectRatio(1, contentMode: .fit)
    }
}

/// The two small lines below the ring: unit/goal and the period.
struct WidgetCaption: View {
    let entry: ConfigEntry
    var alignment: HorizontalAlignment = .center
    /// The text on several short lines (small widget, next to the ring).
    var stacked = false

    var body: some View {
        let d = entry.data
        VStack(alignment: alignment, spacing: 1) {
            if stacked && entry.display == .percent {
                // Small widget: little room next to the ring, so the minutes get their own line.
                Text("\(Int(d.minutes.rounded())) min")
                    .font(.caption2.weight(.semibold))
                Text("of \(Int(d.goal.rounded())) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                (entry.display == .percent
                 ? Text("% · \(Int(d.minutes.rounded())) of \(Int(d.goal.rounded())) min")
                 : Text("of \(Int(d.goal.rounded())) min"))
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

/// Subtle gradient behind Home Screen widgets: warm white → soft pink (dark: deep red-brown → black).
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
            // The ring with the text next to it and the chart below.
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
                        Text("of \(Int(d.goal.rounded())) min · \(d.percent) %")
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
                // The split across heart rate zones (not for older data).
                if let zones = d.zones, !zones.isEmpty {
                    ZoneBar(slices: zones)
                }
            }
        }
    }
}

/// Lock Screen: the small round one is the same two rings as on the watch (ring or heart); rectangular and inline are
/// unchanged.
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

/// Home Screen (small, medium with chart, large with chart) and StandBy.
struct HeartMinutesHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HeartMinutesHome", intent: HeartMinutesHomeConfig.self,
                               provider: ConfigProvider<HeartMinutesHomeConfig>()) { entry in
            HomeWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes")
        .description("Heart Minutes towards your goal – choose the period and minutes or percent.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Lock Screen: round heart, rectangular and inline.
struct HeartMinutesLockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "HeartMinutesLock", intent: HeartMinutesLockConfig.self,
                               provider: ConfigProvider<HeartMinutesLockConfig>()) { entry in
            LockWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes")
        .description("Heart Minutes on the Lock Screen – choose the period, minutes or percent, and heart or ring.")
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
