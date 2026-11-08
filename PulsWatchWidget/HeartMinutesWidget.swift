import SwiftUI
import WidgetKit

/// Rund ring i Aktivitet-stil, der fyldes mod ugens mål og fortsætter rundt over 100 %.
struct HeartMinutesBigRingPercentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesBigRingPercent", provider: HeartMinutesProvider()) { entry in
            HeartMinutesBigRingView(entry: entry, center: .percent)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes – ring")
        .description("Ring, der fyldes mod ugens mål og fortsætter rundt over 100 %, med procent i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Hjerte-ring: hjertets kant fyldes mod ugens mål, med procent i midten.
struct HeartMinutesHeartRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesHeartRing", provider: HeartMinutesProvider()) { entry in
            HeartMinutesHeartRingView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName("Heart Minutes – hjerte")
        .description("Hjertets kant fyldes mod ugens mål, med procent i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct HeartMinutesWidgets: WidgetBundle {
    var body: some Widget {
        HeartMinutesBigRingPercentWidget()
        HeartMinutesHeartRingWidget()
    }
}
