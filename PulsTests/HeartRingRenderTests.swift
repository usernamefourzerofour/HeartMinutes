import SwiftUI
import Testing
@testable import Puls

/// Tegner hjerte-ringen og tjekker, at intet males uden for hjertet (fx en firkant over målet).
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
        // Hjørnerne nederst ligger altid uden for hjertet.
        #expect(alpha(at: CGPoint(x: 195, y: 195), in: image) == 0)
        #expect(alpha(at: CGPoint(x: 4, y: 195), in: image) == 0)
        #expect(alpha(at: CGPoint(x: 195, y: 150), in: image) == 0)
    }
}
