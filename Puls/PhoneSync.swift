import Foundation
import WatchConnectivity

/// Sender indstillingerne til Apple Watch-appen, så komplikationen regner som iPhone-appen.
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    /// De indstillinger, der påvirker beregningen af Heart Minutes.
    static let keys = [
        "includeBackground", "includeWorkouts", "moderateWeight", "vigorousWeight", "weeklyGoal",
        "onlyWhenActive", "age", "zoneMode", "manualMaxHR", "manualModerate", "manualVigorous",
        "maxGapSeconds", "workoutGaps", "interpolation", "minutesSource", "activitySource",
        "activeBridgeSeconds", "watchPeriod",
    ]

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sender de aktuelle indstillinger (kun den nyeste udgave leveres til uret).
    func sendSettings() {
        let session = WCSession.default
        guard WCSession.isSupported(), session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled else { return }
        var context: [String: Any] = [:]
        for key in Self.keys {
            if let value = UserDefaults.standard.object(forKey: key) { context[key] = value }
        }
        try? session.updateApplicationContext(context)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if activationState == .activated { sendSettings() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
