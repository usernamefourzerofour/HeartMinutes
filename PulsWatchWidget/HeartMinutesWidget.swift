import SwiftUI
import WidgetKit

/// Rund ring i Aktivitet-stil, der fyldes mod ugens mål og fortsætter rundt over 100 %.
struct BigRingWidget: Widget {
    let kind: String
    let center: CenterValue

    var body: some WidgetConfiguration {
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
struct HeartRingWidget: Widget {
    let kind: String
    let center: CenterValue

    var body: some WidgetConfiguration {
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

@main
struct HeartMinutesWidgets: WidgetBundle {
    var body: some Widget {
        // De eksisterende "kind"-navne beholdes, så komplikationer på urskiven bliver siddende.
        BigRingWidget(kind: "HeartMinutesBigRingPercent", center: .percent)
        BigRingWidget(kind: "HeartMinutesBigRingMinutes", center: .minutes)
        HeartRingWidget(kind: "HeartMinutesHeartRing", center: .percent)
        HeartRingWidget(kind: "HeartMinutesHeartRingMinutes", center: .minutes)
    }
}
