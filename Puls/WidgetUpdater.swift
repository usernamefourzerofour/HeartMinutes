import Foundation
import UIKit
import BackgroundTasks
import WidgetKit

/// Calculates this week's Heart Minutes and saves them for the widgets (App Group), also in the background.
enum WidgetUpdater {
    static let refreshID = "dk.erik.puls.refresh"

    @MainActor
    /// `allowDecrease`: only when the app is open – in the background the numbers must not drop (see
    /// `ComplicationStore.shouldReplace`).
    static func update(allowDecrease: Bool = false) async {
        // When the phone is locked, Health data is encrypted and can't (fully) be read – we would save numbers that are
        // too low. Wait for the next time instead.
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        // Empty if Health couldn't be read – then the saved numbers are kept.
        for (period, data) in await HealthManager.summaries() {
            ComplicationStore.saveIfValid(data, for: period, allowDecrease: allowDecrease)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Asks iOS to wake the app again in about 30 min (iOS decides the exact time).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = .now.addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
