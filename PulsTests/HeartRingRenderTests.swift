import SwiftUI
import Testing
@testable import Puls

/// Draws the heart ring and checks that nothing is painted outside the heart (e.g. a square above the goal).
@MainActor
struct HeartRingRenderTests {
    private func alpha(at point: CGPoint, in image: CGImage) -> UInt8 {
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -point.x, y: -(CGFloat(image.height) - 1 - point.y),
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        return pixel[3]
    }

    @Test(arguments: [0.5, 1.04, 1.47, 2.2, 3.1])
    func nothingDrawnOutsideTheHeart(fraction: Double) throws {
        let view = ShapeProgressRing(shape: HeartOutlineShape(), fraction: fraction, value: "",
                                     thickness: 0.13, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .frame(width: 200, height: 200)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        // The bottom corners are always outside the heart.
        #expect(alpha(at: CGPoint(x: 195, y: 195), in: image) == 0)
        #expect(alpha(at: CGPoint(x: 4, y: 195), in: image) == 0)
        #expect(alpha(at: CGPoint(x: 195, y: 150), in: image) == 0)
    }

    /// Writes previews of the ring to /tmp/hm-renders (for looking at the ring's end; ignored if it can't write).
    @Test(arguments: [0.5, 0.9, 0.96, 1.04, 1.47, 2.2])
    func writePreview(fraction: Double) throws {
        let view = ShapeProgressRing(shape: HeartOutlineShape(), fraction: fraction, value: "\(Int(fraction * 150))",
                                     thickness: 0.13, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .frame(width: 200, height: 200)
            .padding(10)
            .background(Color.white)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let dir = URL(fileURLWithPath: "/tmp/hm-renders")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent("ring-\(Int(fraction * 100)).png"))
    }
}
