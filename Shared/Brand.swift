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
