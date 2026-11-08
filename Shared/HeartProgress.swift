import SwiftUI
import WidgetKit

/// Hjerteformen fra app-ikonet (tegnet i et 220×220-koordinatsystem, skaleret ind i rammen).
struct HeartShape: Shape {
    /// Hjertets omsluttende kasse i ikonets koordinater.
    static let box = CGRect(x: 34, y: 46, width: 152, height: 132)

    static func transform(for rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / box.width, rect.height / box.height)
        let dx = rect.midX - box.midX * scale
        let dy = rect.midY - box.midY * scale
        return CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 110, y: 178))
        p.addCurve(to: CGPoint(x: 62, y: 62), control1: CGPoint(x: 40, y: 128), control2: CGPoint(x: 34, y: 82))
        p.addCurve(to: CGPoint(x: 110, y: 74), control1: CGPoint(x: 84, y: 46), control2: CGPoint(x: 104, y: 58))
        p.addCurve(to: CGPoint(x: 158, y: 62), control1: CGPoint(x: 116, y: 58), control2: CGPoint(x: 136, y: 46))
        p.addCurve(to: CGPoint(x: 110, y: 178), control1: CGPoint(x: 186, y: 82), control2: CGPoint(x: 180, y: 128))
        p.closeSubpath()
        return p.applying(Self.transform(for: rect))
    }
}

/// Et "fejet" stykke fra kl. 12 og med uret – andelen af ugens mål.
struct SweepShape: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let t = HeartShape.transform(for: rect)
        let center = CGPoint(x: 110, y: 110).applying(t)
        let radius = 140 * t.a
        var p = Path()
        let f = min(max(fraction, 0), 1)
        guard f > 0 else { return p }
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: .degrees(-90),
                 endAngle: .degrees(-90 + 360 * f), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// Hjertet fejes op mod ugens mål: svagt hjerte bagved, fyldt stykke ovenpå.
struct HeartProgress: View {
    var fraction: Double
    var color: Color = .pink

    var body: some View {
        ZStack {
            HeartShape().fill(color.opacity(0.3))
            SweepShape(fraction: fraction).fill(color).clipShape(HeartShape())
        }
    }
}

/// Hjertets omrids tegnet fra kløften øverst og med uret – så det kan "trimmes" som en ring.
struct HeartOutlineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 110, y: 74))
        p.addCurve(to: CGPoint(x: 158, y: 62), control1: CGPoint(x: 116, y: 58), control2: CGPoint(x: 136, y: 46))
        p.addCurve(to: CGPoint(x: 110, y: 178), control1: CGPoint(x: 186, y: 82), control2: CGPoint(x: 180, y: 128))
        p.addCurve(to: CGPoint(x: 62, y: 62), control1: CGPoint(x: 40, y: 128), control2: CGPoint(x: 34, y: 82))
        p.addCurve(to: CGPoint(x: 110, y: 74), control1: CGPoint(x: 84, y: 46), control2: CGPoint(x: 104, y: 58))
        p.closeSubpath()   // pæn samling i kløften, når hele hjertet tegnes
        return p.applying(HeartShape.transform(for: rect))
    }
}

/// "Hjerte-ring": omridset fyldes med uret mod målet, ligesom en ring – men formet som et hjerte.
struct HeartRingProgress: View {
    var fraction: Double
    var color: Color = .pink
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            HeartOutlineShape()
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))
            HeartOutlineShape()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .widgetAccentable()
        }
        .padding(lineWidth / 2)
    }
}
