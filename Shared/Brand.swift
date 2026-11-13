import SwiftUI

/// Appens fælles udtryk: én accentfarve (den røde fra app-ikonet) og bløde farveovergange.
enum Brand {
    static let accent = Color(red: 0.89, green: 0.17, blue: 0.31)

    /// Blød flade under en kurve: farven foroven, næsten gennemsigtig forneden.
    static func area(_ color: Color = accent, top: Double = 0.38) -> LinearGradient {
        LinearGradient(colors: [color.opacity(top), color.opacity(0.04)], startPoint: .top, endPoint: .bottom)
    }
}

/// Hjerte-ringen, der kan animeres (fyldes blødt op, når tallet ændrer sig).
struct AnimatedHeartRing: View, Animatable {
    var fraction: Double
    var value: String

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    var body: some View {
        ShapeProgressRing(shape: HeartOutlineShape(), fraction: fraction, value: value,
                          thickness: 0.13, textY: 0.46, textWidth: 0.46, textSize: 0.3)
    }
}

/// Hjerte-ringen, der tæller op: fra 0, når den vises, når appen åbnes igen fra baggrunden, og
/// når `resetKey` skifter (ny periode); ellers fra det viste tal til det nye. Konstant fart: én hel
/// omgang (100 %) pr. sekund. Bruges i iPhone-appen og på uret.
struct CountingHeartRing: View {
    let total: Double
    let goal: Double
    var resetKey: String = ""
    @State private var shown = 0.0
    @State private var run = 0
    @State private var wasInBackground = false
    @State private var countedKey: String?
    @Environment(\.scenePhase) private var scenePhase

    private var fraction: Double { goal > 0 ? max(0, total / goal) : 0 }
    /// Tallet i midten tæller med op, så det passer til ringen undervejs.
    private var shownMinutes: Int { goal > 0 ? Int((shown * goal).rounded()) : Int(total.rounded()) }

    var body: some View {
        AnimatedHeartRing(fraction: shown, value: "\(shownMinutes)")
            // Animeres trin for trin (i stedet for withAnimation), så det virker pålideligt i lister.
            .task(id: "\(fraction)-\(run)-\(resetKey)") {
                if resetKey != countedKey { countedKey = resetKey; shown = 0 }
                await fill(to: fraction)
            }
            .onChange(of: scenePhase) { _, phase in
                // Kun efter baggrunden – ikke fx når Kontrolcenter lukkes.
                if phase == .background { wasInBackground = true }
                if phase == .active && wasInBackground { wasInBackground = false; shown = 0; run += 1 }
            }
    }

    private func fill(to target: Double) async {
        let start = shown
        let lapsPerSecond = 1.0
        let duration = max(abs(target - start) / lapsPerSecond, 0.01)
        let begin = Date.now
        while !Task.isCancelled {
            let t = min(Date.now.timeIntervalSince(begin) / duration, 1)
            shown = start + (target - start) * t
            if t >= 1 { break }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}

extension ZoneSlice {
    var color: Color { Color(red: r, green: g, blue: b) }
}

/// Én vandret bjælke i zonefarverne: hvor minutterne er optjent.
struct ZoneBar: View {
    let slices: [ZoneSlice]
    var showLabels = true

    var body: some View {
        let shown = slices.filter { $0.minutes > 0 }
        let total = shown.reduce(0) { $0 + $1.minutes }
        VStack(alignment: .leading, spacing: 5) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    if shown.isEmpty {
                        Rectangle().fill(Color.gray.opacity(0.25))
                    } else {
                        let width = geo.size.width - CGFloat(shown.count - 1) * 2
                        ForEach(Array(shown.enumerated()), id: \.offset) { _, s in
                            Rectangle().fill(s.color)
                                .frame(width: max(2, width * s.minutes / total))
                        }
                    }
                }
            }
            .frame(height: 8)
            .clipShape(Capsule())
            if showLabels && !shown.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(shown.enumerated()), id: \.offset) { _, s in
                        HStack(spacing: 3) {
                            Circle().fill(s.color).frame(width: 7, height: 7)
                            Text("\(s.name) \(Int(s.minutes.rounded())) min")
                        }
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
    }
}
