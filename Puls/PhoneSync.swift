import Foundation
import WatchConnectivity

/// Sends the settings to the Apple Watch app so the complication calculates like the iPhone app.
final class PhoneSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSync()

    /// The settings that affect the Heart Minutes calculation.
    static let keys = [
        "includeBackground", "includeWorkouts", "weeklyGoal",
        "onlyWhenActive", "age", "zoneModel", "maxHRSource", "manualMaxHR",
        "zonePercents.two", "zoneWeights.two", "zonePercents.five", "zoneWeights.five",
        "maxGapSeconds", "workoutGaps", "interpolation", "activitySource",
        "activeBridgeSeconds", "watchPeriod",
    ]

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Sends the current settings (only the newest version is delivered to the watch).
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
