import SwiftUI
import WidgetKit

/// Round ring in Activity style that fills toward the weekly goal and keeps going past 100 %.
struct BigRingWidget {
    static func make(kind: String, center: CenterValue) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeartMinutesProvider()) { entry in
            HeartMinutesBigRingView(entry: entry, center: center)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName(center == .percent ? Text("Heart Minutes – ring %") : Text("Heart Minutes – ring min"))
        .description(center == .percent
                     ? Text("A ring that fills towards the weekly goal and keeps going past 100 %, with percent in the middle.")
                     : Text("A ring that fills towards the weekly goal and keeps going past 100 %, with minutes in the middle."))
        .supportedFamilies([.accessoryCircular])
    }
}

/// Heart ring: the outline of the heart fills toward the weekly goal.
struct HeartRingWidget {
    static func make(kind: String, center: CenterValue) -> some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeartMinutesProvider()) { entry in
            HeartMinutesHeartRingView(entry: entry, center: center)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "heartminutes://minutes"))
        }
        .configurationDisplayName(center == .percent ? Text("Heart Minutes – heart %") : Text("Heart Minutes – heart min"))
        .description(center == .percent
                     ? Text("The outline of the heart fills towards the weekly goal, with percent in the middle.")
                     : Text("The outline of the heart fills towards the weekly goal, with minutes in the middle."))
        .supportedFamilies([.accessoryCircular])
    }
}

// The existing "kind" names are kept so complications on the watch face stay in place.
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
