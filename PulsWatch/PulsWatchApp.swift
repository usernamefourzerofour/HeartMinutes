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

/// Regner ugens Heart Minutes på uret (samme beregning som på iPhone) og gemmer dem til komplikationen.
@Observable @MainActor
final class WatchModel {
    static let shared = WatchModel()
    nonisolated static let refreshID = "heartminutes"

    private(set) var data = ComplicationStore.load() ?? ComplicationData(minutes: 0, goal: 150, updated: .distantPast)
    private(set) var isLoading = false
    private let sync = WatchSync()

    func refresh(askForAccess: Bool) async {
        isLoading = true
        defer { isLoading = false }
        // Ny HealthManager hver gang, så indstillinger synkroniseret fra iPhone bliver brugt.
        if askForAccess { await HealthManager().requestAuthorization() }
        data = await HealthManager.weekSummary()
        ComplicationStore.save(data)
        WidgetCenter.shared.reloadAllTimelines()
        scheduleNextRefresh()
    }

    private func scheduleNextRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now.addingTimeInterval(30 * 60),
            userInfo: WatchModel.refreshID as NSString) { _ in }
    }
}
