import SwiftUI

struct ContentView: View {
    @Environment(HealthManager.self) private var health
    @Environment(\.scenePhase) private var scenePhase
    /// When the period was last loaded (to move "this week"/"today" along when the app comes back).
    @State private var loadedAt = Date.now
    @State private var ready = false
    /// The selected period (remembered when switching to Settings and back).
    @State private var interval = Period.thisWeek()
    @State private var tab = AppTab.overview
    /// Set when the app is opened from a widget, so Overview scrolls up to the minutes chart.
    @State private var showMinutes = 0

    enum AppTab: Hashable { case overview, settings }

    var body: some View {
        Group {
            if ready {
                TabView(selection: $tab) {
                    Tab("Overview", systemImage: "heart.fill", value: AppTab.overview) {
                        OverviewView(interval: $interval, showMinutes: showMinutes)
                    }
                    Tab("Settings", systemImage: "gearshape", value: AppTab.settings) { SettingsView() }
                }
            } else {
                ProgressView("Connecting to Health…")
            }
        }
        .tint(Brand.accent)
        .onOpenURL { url in
            // Tap on a widget/complication: show the minutes chart.
            guard url.scheme == "heartminutes" else { return }
            tab = .overview
            showMinutes += 1
        }
        .task {
            await health.requestAuthorization()
            ready = true
        }
        .task(id: interval) {
            guard ready else { return }
            loadedAt = .now
            await health.loadPeriod(interval)
        }
        // The app comes back: fetch new measurements and move a "now" period along (e.g. to a new day).
        .onChange(of: scenePhase) { _, phase in
            guard ready, phase == .active else { return }
            let updated = Period.refreshed(interval, from: loadedAt)
            if updated != interval {
                interval = updated          // .task(id:) loads
            } else {
                loadedAt = .now
                Task { await health.loadPeriod(interval) }
            }
        }
        .onChange(of: ready) { _, isReady in
            if isReady { Task { await health.loadPeriod(interval) } }
        }
    }
}
