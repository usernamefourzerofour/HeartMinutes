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
                                     thickness: 0.12, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .frame(width: 200, height: 200)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        // The bottom corners are always outside the heart.
        #expect(alpha(at: CGPoint(x: 195, y: 195), in: image) == 0)
        #expect(alpha(at: CGPoint(x: 4, y: 195), in: image) == 0)
        #expect(alpha(at: CGPoint(x: 195, y: 150), in: image) == 0)
    }

    /// A frame wider than it is tall (like the overview): the heart then reaches the bottom edge, and the stroke there
    /// must be drawn in full (the progress, not just the faint track behind it).
    @Test func strokeNotCutOffAtTheBottom() throws {
        let view = ShapeProgressRing(shape: HeartOutlineShape(), fraction: 1.5, value: "",
                                     thickness: 0.12, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .frame(width: 300, height: 200)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        #expect(alpha(at: CGPoint(x: 150, y: 196), in: image) > 200)
    }

    /// The round ring touches all four edges of its frame; the stroke must be drawn in full there (it was cut off
    /// into an octagon on the watch).
    @Test func roundRingNotCutOffAtTheEdges() throws {
        let view = ShapeProgressRing(shape: TopCircle(), fraction: 0.99, value: "")
            .frame(width: 200, height: 200)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        for point in [CGPoint(x: 100, y: 197), CGPoint(x: 3, y: 100), CGPoint(x: 197, y: 100)] {
            #expect(alpha(at: point, in: image) > 200)
        }
    }

    private func png(_ fraction: Double, scale: CGFloat, dark: Bool = false) -> Data? {
        let view = ShapeProgressRing(shape: HeartOutlineShape(), fraction: fraction, value: "\(Int(fraction * 150))",
                                     thickness: 0.12, textY: 0.46, textWidth: 0.46, textSize: 0.3)
            .frame(width: 200, height: 200)
            .padding(10)
            .background(dark ? Color.black : Color.white)
            .environment(\.colorScheme, dark ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.uiImage?.pngData()
    }

    private func write(_ data: Data?, _ name: String, in folder: String) {
        guard let data else { return }
        let dir = URL(fileURLWithPath: "/tmp/hm-renders").appendingPathComponent(folder)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: dir.appendingPathComponent(name))
    }

    /// Writes previews of the ring to /tmp/hm-renders (for looking at the ring's end; ignored if it can't write).
    @Test(arguments: [0.1, 0.5, 0.9, 0.96, 0.99, 1.01, 1.04, 1.47, 2.2])
    func writePreview(fraction: Double) {
        write(png(fraction, scale: 3), "ring-\(Int((fraction * 100).rounded())).png", in: ".")
        write(png(fraction, scale: 3, dark: true), "dark-\(Int((fraction * 100).rounded())).png", in: ".")
    }

    /// Every frame of the count-up from 0 to 300 % (1 % per frame) to /tmp/hm-renders/frames. Only when the test runner
    /// has HM_FRAMES set (xcodebuild: TEST_RUNNER_HM_FRAMES=1), as it takes a while.
    @Test func writeAnimationFrames() {
        guard ProcessInfo.processInfo.environment["HM_FRAMES"] != nil else { return }
        for percent in 0...300 {
            write(png(Double(percent) / 100, scale: 2), String(format: "f%03d.png", percent), in: "frames")
        }
    }
}
