import SwiftUI
import WidgetKit

/// The heart shape from the app icon (drawn in a 220×220 coordinate system, scaled into the frame).
struct HeartShape: Shape {
    /// The heart's bounding box in the icon's coordinates.
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

/// A "swept" piece from 12 o'clock, clockwise – the fraction of the weekly goal.
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

/// The heart is swept toward the weekly goal: a faint heart behind, the filled piece on top.
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

/// The heart's outline (the middle of the stroke) drawn from the cleft at the top, clockwise – so it can be trimmed like
/// a ring. Built from circles so it is smooth everywhere: two round lobes, slightly curved sides and a rounded tip and
/// cleft. The tip and the cleft are rounded with half the stroke width, so the stroke's outer edge there has a radius of
/// one stroke width and its inner edge just comes to a point (no sharp corners where the stroke could fold over).
struct HeartOutlineShape: Shape {
    /// The stroke width the corners are rounded for, as a fraction of the size (as in `ShapeProgressRing`).
    var thickness: CGFloat = 0.12

    func path(in rect: CGRect) -> Path {
        // In the icon's coordinates (see `HeartShape.box`). The ring draws the shape inset by half a stroke, so one
        // stroke width is thickness / (1 − thickness) of the box width.
        let box = HeartShape.box
        let corner = thickness / (1 - thickness) * box.width / 2   // half a stroke width
        let mid = box.midX                                        // 110
        let lobe = CGPoint(x: mid + 33, y: 89), lobeRadius: CGFloat = 33
        let sideRadius: CGFloat = 230
        let tip = CGPoint(x: mid, y: box.maxY + 1 - corner)       // the lowest point (just below the box)
        // The cleft: a circle above it that touches both lobes.
        let cleft = CGPoint(x: mid, y: lobe.y - sqrt(pow(lobeRadius + corner, 2) - pow(lobe.x - mid, 2)))
        // The side: a large circle that touches the lobe and the tip from the inside.
        let side = Self.touchingCircle(lobe, lobeRadius, tip, corner, radius: sideRadius)
        func angle(_ c: CGPoint, toward p: CGPoint) -> Double { atan2(Double(p.y - c.y), Double(p.x - c.x)) }
        func mirrored(_ a: Double) -> Double { .pi - a }
        let cleftToLobe = angle(cleft, toward: lobe)           // where the cleft meets the lobe (seen from the cleft)
        let lobeToCleft = angle(lobe, toward: cleft)
        let lobeToSide = angle(side, toward: lobe)              // where the lobe meets the side
        let sideToTip = angle(side, toward: tip)                // where the side meets the tip

        // Angles grow clockwise on screen (the y axis points down). Each arc continues exactly from where the previous
        // one ended: Path.addArc adds a tiny connecting line when the points differ by a rounding error, and a stroke's
        // join at such a line (random direction) showed as a circle or a spike.
        var p = Path()
        p.move(to: CGPoint(x: cleft.x, y: cleft.y + corner))
        Self.arc(&p, center: cleft, radius: corner, from: .pi / 2, to: cleftToLobe)
        Self.arc(&p, center: lobe, radius: lobeRadius, from: lobeToCleft, to: lobeToSide)
        Self.arc(&p, center: side, radius: sideRadius, from: lobeToSide, to: sideToTip)
        Self.arc(&p, center: tip, radius: corner, from: sideToTip, to: mirrored(sideToTip))
        let otherSide = CGPoint(x: 2 * mid - side.x, y: side.y), otherLobe = CGPoint(x: 2 * mid - lobe.x, y: lobe.y)
        Self.arc(&p, center: otherSide, radius: sideRadius, from: mirrored(sideToTip), to: mirrored(lobeToSide))
        Self.arc(&p, center: otherLobe, radius: lobeRadius, from: mirrored(lobeToSide), to: mirrored(lobeToCleft))
        Self.arc(&p, center: cleft, radius: corner, from: mirrored(cleftToLobe), to: .pi / 2)
        p.closeSubpath()
        return p.applying(HeartShape.transform(for: rect))
    }

    /// An arc from angle `a0` to `a1` (radians; increasing = clockwise on screen) as Bézier curves (at most 90° each),
    /// continuing from the path's current point without a connecting line.
    private static func arc(_ p: inout Path, center c: CGPoint, radius r: CGFloat, from a0: Double, to a1: Double) {
        let parts = max(1, Int((abs(a1 - a0) / (.pi / 2)).rounded(.up)))
        let step = (a1 - a0) / Double(parts)
        let k = 4.0 / 3.0 * tan(step / 4)
        for n in 0..<parts {
            let a = a0 + step * Double(n), b = a + step
            let p1 = CGPoint(x: c.x + r * (cos(a) - k * sin(a)), y: c.y + r * (sin(a) + k * cos(a)))
            let p3 = CGPoint(x: c.x + r * cos(b), y: c.y + r * sin(b))
            let p2 = CGPoint(x: p3.x + r * k * sin(b), y: p3.y - r * k * cos(b))
            p.addCurve(to: p3, control1: p1, control2: p2)
        }
    }

    /// The centre of a circle with `radius` that touches two smaller circles from the outside of them (both lie
    /// inside it), on the side toward the heart's middle.
    private static func touchingCircle(_ c1: CGPoint, _ r1: CGFloat, _ c2: CGPoint, _ r2: CGFloat,
                                       radius: CGFloat) -> CGPoint {
        let d1 = radius - r1, d2 = radius - r2
        let dx = c2.x - c1.x, dy = c2.y - c1.y
        let l = sqrt(dx * dx + dy * dy)
        let ux = dx / l, uy = dy / l
        let along = (d1 * d1 - d2 * d2 + l * l) / (2 * l)
        let h = sqrt(max(d1 * d1 - along * along, 0))
        let a = CGPoint(x: c1.x + ux * along - uy * h, y: c1.y + uy * along + ux * h)
        let b = CGPoint(x: c1.x + ux * along + uy * h, y: c1.y + uy * along - ux * h)
        return a.x < b.x ? a : b
    }
}

/// "Heart ring": the outline fills clockwise toward the goal, like a ring – but shaped like a heart.
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
