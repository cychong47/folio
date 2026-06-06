import XCTest
@testable import Photolog

final class PostDraftStoreTests: XCTestCase {
    func testCreateDraftCopiesCurationPayloadIntoIndependentPost() {
        let mainPost = PendingPost()
        mainPost.slug = "main-window-post"

        let store = PostDraftStore()
        let date = Calendar.current.date(from: DateComponents(
            year: 2023,
            month: 11,
            day: 14,
            hour: 12
        ))!
        let photos = [
            ExportedPhoto(
                filename: "2023-11-14-photo.jpg",
                markdownPath: "/images/2023-11-14-photo.jpg",
                localURL: URL(fileURLWithPath: "/tmp/2023-11-14-photo.jpg"),
                exifDate: date
            )
        ]

        let draftID = store.createDraft(markdown: "![Photo](/images/2023-11-14-photo.jpg)", date: date, photos: photos)
        let draft = store.draft(for: draftID)

        XCTAssertEqual(draft?.photos.map(\.filename), ["2023-11-14-photo.jpg"])
        XCTAssertEqual(draft?.markdownBody, "![Photo](/images/2023-11-14-photo.jpg)")
        XCTAssertEqual(draft?.slug, "2023-11-14")
        XCTAssertEqual(draft?.postDate, date)
        XCTAssertEqual(mainPost.slug, "main-window-post")
        XCTAssertTrue(mainPost.photos.isEmpty)
    }
}
