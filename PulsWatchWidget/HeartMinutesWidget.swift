import SwiftUI
import WidgetKit

struct HeartMinutesPercentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesPercent", provider: HeartMinutesProvider()) { entry in
            HeartMinutesView(entry: entry, center: .percent)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – procent")
        .description("Ugens Heart Minutes i procent af målet.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct HeartMinutesMinutesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesMinutes", provider: HeartMinutesProvider()) { entry in
            HeartMinutesView(entry: entry, center: .minutes)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – minutter")
        .description("Ugens Heart Minutes i minutter.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

/// Traditionel ring (som Apples egne komplikationer) med procent i midten.
struct HeartMinutesRingPercentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesRingPercent", provider: HeartMinutesProvider()) { entry in
            HeartMinutesRingView(entry: entry, center: .percent)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – ring %")
        .description("Ring, der fyldes mod ugens mål, med procent i midten.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

/// Traditionel ring med minutter i midten.
struct HeartMinutesRingMinutesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesRingMinutes", provider: HeartMinutesProvider()) { entry in
            HeartMinutesRingView(entry: entry, center: .minutes)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – ring min")
        .description("Ring, der fyldes mod ugens mål, med minutter i midten.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

/// Hjerte-ring: hjertets omrids fyldes som en ring, med procent i midten.
struct HeartMinutesHeartRingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesHeartRing", provider: HeartMinutesProvider()) { entry in
            HeartMinutesHeartRingView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – hjerte-ring %")
        .description("Hjertets kant fyldes mod ugens mål, med procent i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Tyk ring i Aktivitet-stil med procent i midten.
struct HeartMinutesBigRingPercentWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesBigRingPercent", provider: HeartMinutesProvider()) { entry in
            HeartMinutesBigRingView(entry: entry, center: .percent)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – tyk ring %")
        .description("Én tyk ring, der fyldes mod ugens mål og fortsætter rundt over 100 %, med procent i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Tyk ring i Aktivitet-stil med minutter i midten.
struct HeartMinutesBigRingMinutesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HeartMinutesBigRingMinutes", provider: HeartMinutesProvider()) { entry in
            HeartMinutesBigRingView(entry: entry, center: .minutes)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Heart Minutes – tyk ring min")
        .description("Én tyk ring, der fyldes mod ugens mål og fortsætter rundt over 100 %, med minutter i midten.")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct HeartMinutesWidgets: WidgetBundle {
    var body: some Widget {
        HeartMinutesPercentWidget()
        HeartMinutesMinutesWidget()
        HeartMinutesRingPercentWidget()
        HeartMinutesRingMinutesWidget()
        HeartMinutesHeartRingWidget()
        HeartMinutesBigRingPercentWidget()
        HeartMinutesBigRingMinutesWidget()
    }
}
