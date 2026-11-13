import SwiftUI
import WatchKit
import WidgetKit

@main
struct PulsWatchApp: App {
    @State private var model = WatchModel.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(model)
                .task { await model.refresh(askForAccess: true) }
        }
        .backgroundTask(.appRefresh(WatchModel.refreshID)) {
            await WatchModel.shared.refresh(askForAccess: false)
        }
    }
}

/// Calculates this week's Heart Minutes on the watch (the same calculation as on iPhone) and saves them for the
/// complication.
@Observable @MainActor
final class WatchModel {
    static let shared = WatchModel()
    nonisolated static let refreshID = "heartminutes"

    private(set) var period = ComplicationStore.watchPeriod
    private(set) var data = ComplicationStore.load(for: ComplicationStore.watchPeriod)
        ?? ComplicationData(minutes: 0, goal: 150, updated: .distantPast)
    private(set) var isLoading = false
    private let sync = WatchSync()

    func refresh(askForAccess: Bool) async {
        isLoading = true
        defer { isLoading = false }
        // A new HealthManager each time, so settings synced from iPhone are used.
        if askForAccess { await HealthManager().requestAuthorization() }
        // No data (error) or a lower number in the background: keep the saved number. With the app open (askForAccess)
        // the number may drop, e.g. after changed settings. The period is chosen in the iPhone app (e.g. Today, This
        // week, Last 7 days).
        let period = ComplicationStore.watchPeriod
        if let new = await HealthManager.summary(for: period) {
            ComplicationStore.saveIfValid(new, for: period, allowDecrease: askForAccess)
        }
        self.period = period
        if let stored = ComplicationStore.load(for: period) { data = stored }
        WidgetCenter.shared.reloadAllTimelines()
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now.addingTimeInterval(30 * 60),
            userInfo: WatchModel.refreshID as NSString) { _ in }
    }
}
