import Testing
import UIKit
@testable import Replr

/// Every screenshot capture path (Back Tap intent, Quick Reply, in-keyboard
/// native screenshot) must produce the same History-card preview.
struct CaptureThumbnailTests {
    private func solidImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func scalesTo80PointWidthJPEG() throws {
        let data = try #require(CaptureThumbnail.make(solidImage(width: 400, height: 800)))
        let decoded = try #require(UIImage(data: data))
        #expect(decoded.size.width == 80)
        #expect(decoded.size.height == 160)
        #expect(data.count < 50_000)   // it's a preview, not a copy of the shot
    }

    @Test func zeroWidthImageReturnsNil() {
        #expect(CaptureThumbnail.make(UIImage()) == nil)
    }
}
