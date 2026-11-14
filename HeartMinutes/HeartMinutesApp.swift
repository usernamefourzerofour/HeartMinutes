import SwiftUI

@main
struct HeartMinutesApp: App {
    @State private var health = HealthManager()
    @Environment(\.scenePhase) private var scenePhase

    init() { PhoneSync.shared.start() }

    var body: some Scene {
        WindowGroup { ContentView().environment(health) }
            .onChange(of: scenePhase) { _, phase in
                // Send the settings to the watch and update widgets when the app is opened or put away.
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
