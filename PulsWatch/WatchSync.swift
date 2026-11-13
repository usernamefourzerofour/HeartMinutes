import Foundation
import WatchConnectivity

/// Receives the settings from the iPhone app so the watch calculates with the same zones and weights.
final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if !session.receivedApplicationContext.isEmpty { apply(session.receivedApplicationContext) }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
        Task { @MainActor in await WatchModel.shared.refresh(askForAccess: false) }
    }

    private func apply(_ settings: [String: Any]) {
        for (key, value) in settings { UserDefaults.standard.set(value, forKey: key) }
        // The complication can only read the App Group – the period is stored there too.
        if let raw = settings["watchPeriod"] as? String, let period = SummaryPeriod(rawValue: raw) {
            ComplicationStore.watchPeriod = period
        }
    }
}
