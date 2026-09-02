import CoreGraphics
import Testing
@testable import WikeyCore

struct LayoutZoneTests {
    private let screen = CGRect(x: -100, y: 40, width: 1200, height: 900)

    @Test func halvesFillVisibleFrameWithoutGap() {
        let left = LayoutZone.leftHalf.frame(in: screen)
        let right = LayoutZone.rightHalf.frame(in: screen)
        #expect(left.minX == screen.minX)
        #expect(right.maxX == screen.maxX)
        #expect(left.maxX == right.minX)
        #expect(left.height == screen.height)
    }

    @Test func thirdsFillVisibleFrameWithoutGap() {
        let left = LayoutZone.leftThird.frame(in: screen)
        let center = LayoutZone.centerThird.frame(in: screen)
        let right = LayoutZone.rightThird.frame(in: screen)
        #expect(left.minX == screen.minX)
        #expect(left.maxX == center.minX)
        #expect(center.maxX == right.minX)
        #expect(right.maxX == screen.maxX)
    }

    @Test func quadrantsCoverScreen() {
        let topLeft = LayoutZone.topLeft.frame(in: screen)
        let bottomRight = LayoutZone.bottomRight.frame(in: screen)
        #expect(topLeft.minX == screen.minX)
        #expect(topLeft.maxY == screen.maxY)
        #expect(bottomRight.maxX == screen.maxX)
        #expect(bottomRight.minY == screen.minY)
        #expect(topLeft.width == screen.width / 2)
        #expect(bottomRight.height == screen.height / 2)
    }
}
