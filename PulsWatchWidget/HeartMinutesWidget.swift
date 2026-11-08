import SwiftUI
import WidgetKit

/// Rund ring i Aktivitet-stil, der fyldes mod ugens mål og fortsætter rundt over 100 %.
struct BigRingWidget {
    static func make(kind: String, center: CenterValue) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeartMinutesProvider()) { entry in
            HeartMinutesBigRingView(entry: entry, center: center)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName(center == .percent ? "Heart Minutes – ring %" : "Heart Minutes – ring min")
        .description(center == .percent
                     ? "Ring, der fyldes mod ugens mål og fortsætter rundt over 100 %, med procent i midten."
                     : "Ring, der fyldes mod ugens mål og fortsætter rundt over 100 %, med minutter i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Hjerte-ring: hjertets kant fyldes mod ugens mål.
struct HeartRingWidget {
    static func make(kind: String, center: CenterValue) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeartMinutesProvider()) { entry in
            HeartMinutesHeartRingView(entry: entry, center: center)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName(center == .percent ? "Heart Minutes – hjerte %" : "Heart Minutes – hjerte min")
        .description(center == .percent
                     ? "Hjertets kant fyldes mod ugens mål, med procent i midten."
                     : "Hjertets kant fyldes mod ugens mål, med minutter i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

// De eksisterende "kind"-navne beholdes, så komplikationer på urskiven bliver siddende.
struct BigRingPercentWidget: Widget {
    var body: some WidgetConfiguration { BigRingWidget.make(kind: "HeartMinutesBigRingPercent", center: .percent) }
}

struct BigRingMinutesWidget: Widget {
    var body: some WidgetConfiguration { BigRingWidget.make(kind: "HeartMinutesBigRingMinutes", center: .minutes) }
}

struct HeartRingPercentWidget: Widget {
    var body: some WidgetConfiguration { HeartRingWidget.make(kind: "HeartMinutesHeartRing", center: .percent) }
}

struct HeartRingMinutesWidget: Widget {
    var body: some WidgetConfiguration { HeartRingWidget.make(kind: "HeartMinutesHeartRingMinutes", center: .minutes) }
}

@main
struct HeartMinutesWidgets: WidgetBundle {
    var body: some Widget {
        BigRingPercentWidget()
        BigRingMinutesWidget()
        HeartRingPercentWidget()
        HeartRingMinutesWidget()
    }
}
