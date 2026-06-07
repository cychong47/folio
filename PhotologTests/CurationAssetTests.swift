import CoreGraphics
import XCTest
@testable import Photolog

final class CurationAssetTests: XCTestCase {
    func testFilenameIsStoredDisplayData() {
        let asset = CurationAsset(
            filename: "IMG_3271.HEIC",
            timestamp: Date(timeIntervalSince1970: 0),
            pixelSize: .zero
        )

        XCTAssertEqual(asset.filename, "IMG_3271.HEIC")
    }
}
