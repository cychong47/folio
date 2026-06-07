import CoreGraphics
import XCTest
@testable import Photolog

final class MainWindowSizingTests: XCTestCase {
    func testWelcomeFramePreservesWindowCenterWhenItFitsVisibleDisplay() {
        let current = CGRect(x: 100, y: 100, width: 1200, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 2000, height: 1400)

        let frame = MainWindowSizing.frame(
            currentFrame: current,
            targetSize: MainWindowSizing.welcomeSize,
            visibleFrame: visible
        )

        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 500)
        XCTAssertEqual(frame.midX, current.midX)
        XCTAssertEqual(frame.midY, current.midY)
    }

    func testWelcomeFrameStaysInsideVisibleDisplay() {
        let current = CGRect(x: 1500, y: 1000, width: 1200, height: 900)
        let visible = CGRect(x: 0, y: 0, width: 1800, height: 1200)

        let frame = MainWindowSizing.frame(
            currentFrame: current,
            targetSize: MainWindowSizing.welcomeSize,
            visibleFrame: visible
        )

        XCTAssertLessThanOrEqual(frame.maxX, visible.maxX)
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY)
        XCTAssertGreaterThanOrEqual(frame.minX, visible.minX)
        XCTAssertGreaterThanOrEqual(frame.minY, visible.minY)
    }

    func testWelcomeSizeLeavesRoomForBottomAccessBanner() {
        XCTAssertGreaterThanOrEqual(MainWindowSizing.welcomeSize.height, 500)
    }
}
