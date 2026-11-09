import SwiftUI

@main
struct PulsApp: App {
    @State private var health = HealthManager()
    @Environment(\.scenePhase) private var scenePhase

    init() { PhoneSync.shared.start() }

    var body: some Scene {
        WindowGroup { ContentView().environment(health) }
            .onChange(of: scenePhase) { _, phase in
                // Send indstillingerne til uret og opdatér widgets, når appen åbnes eller lægges væk.
                PhoneSync.shared.sendSettings()
                guard phase != .inactive else { return }
                Task { await WidgetUpdater.update(allowDecrease: phase == .active) }
                if phase == .background { WidgetUpdater.schedule() }
            }
            .backgroundTask(.appRefresh(WidgetUpdater.refreshID)) {
                await WidgetUpdater.update()
                WidgetUpdater.schedule()
            }
    }
}
