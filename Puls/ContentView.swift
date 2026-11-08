import SwiftUI

struct ContentView: View {
    @Environment(HealthManager.self) private var health
    @State private var ready = false
    /// Den valgte periode (huskes, når man skifter til Indstillinger og tilbage).
    @State private var interval = Period.thisWeek()

    var body: some View {
        Group {
            if ready {
                TabView {
                    Tab("Overblik", systemImage: "heart.fill") { OverviewView(interval: $interval) }
                    Tab("Indstillinger", systemImage: "gearshape") { SettingsView() }
                }
            } else {
                ProgressView("Forbinder til Sundhed…")
            }
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
