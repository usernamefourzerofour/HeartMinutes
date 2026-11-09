import Foundation
import UIKit
import BackgroundTasks
import WidgetKit

/// Regner ugens Heart Minutes og gemmer dem til widgets (App Group), også i baggrunden.
enum WidgetUpdater {
    static let refreshID = "dk.erik.puls.refresh"

    @MainActor
    /// `allowDecrease`: kun når appen er åben – i baggrunden må tallene ikke falde (se
    /// `ComplicationStore.shouldReplace`).
    static func update(allowDecrease: Bool = false) async {
        // Når telefonen er låst, er Sundhed-data krypteret og kan ikke (helt) læses –
        // så ville vi gemme for lave tal. Vent til næste gang i stedet.
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        // Tom, hvis Sundhed ikke kunne læses – så beholdes de gemte tal.
        for (period, data) in await HealthManager.summaries() {
            ComplicationStore.saveIfValid(data, for: period, allowDecrease: allowDecrease)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Beder iOS om at vække appen igen om ca. 30 min (iOS bestemmer selv det præcise tidspunkt).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshID)
        request.earliestBeginDate = .now.addingTimeInterval(30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
