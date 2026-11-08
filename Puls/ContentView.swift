import SwiftUI

struct ContentView: View {
    @Environment(HealthManager.self) private var health
    @State private var ready = false
    /// Den valgte periode (huskes, når man skifter til Indstillinger og tilbage).
    @State private var interval = Period.thisWeek()
    @State private var tab = AppTab.overview
    /// Sættes, når appen åbnes fra en widget, så Overblik ruller op til minutgrafen.
    @State private var showMinutes = 0

    enum AppTab: Hashable { case overview, settings }

    var body: some View {
        Group {
            if ready {
                TabView(selection: $tab) {
                    Tab("Overblik", systemImage: "heart.fill", value: AppTab.overview) {
                        OverviewView(interval: $interval, showMinutes: showMinutes)
                    }
                    Tab("Indstillinger", systemImage: "gearshape", value: AppTab.settings) { SettingsView() }
                }
            } else {
                ProgressView("Forbinder til Sundhed…")
            }
        }
        .onOpenURL { url in
            // Tryk på en widget/komplikation: vis minutgrafen.
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
            await health.loadPeriod(interval)
        }
        .onChange(of: ready) { _, isReady in
            if isReady { Task { await health.loadPeriod(interval) } }
        }
    }
}
