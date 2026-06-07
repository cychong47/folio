import XCTest
@testable import Photolog

final class PostPreviewBlockTests: XCTestCase {
    func testPreviewMediaCaptionUsesPhotoFilename() {
        let photo = ExportedPhoto(
            filename: "2026-03-15-IMG_0001.jpg",
            markdownPath: "/images/2026/03/2026-03-15-IMG_0001.jpg",
            localURL: URL(fileURLWithPath: "/tmp/2026-03-15-IMG_0001.jpg"),
            exifDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(PostPreviewBlock.mediaCaption(for: photo), "2026-03-15-IMG_0001.jpg")
    }
}
