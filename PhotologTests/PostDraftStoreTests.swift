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

    func testCreateDraftFromPostSummaryCopiesExistingPostForWindowEditing() {
        let store = PostDraftStore()
        let date = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 15,
            hour: 9
        ))!
        let fileURL = URL(fileURLWithPath: "/tmp/content/posts/2026-03-15-trip.md")
        let photo = ExportedPhoto(
            filename: "2026-03-15-photo.jpg",
            markdownPath: "/images/2026-03-15-photo.jpg",
            localURL: URL(fileURLWithPath: "/tmp/static/images/2026-03-15-photo.jpg"),
            exifDate: date
        )
        let summary = PostSummary(
            fileURL: fileURL,
            title: "Trip",
            date: date,
            slug: "trip",
            categories: ["travel"],
            tags: ["spring"],
            series: "Seoul",
            isDraft: false,
            bodyText: "Body text"
        )

        let draftID = store.createDraft(from: summary, photos: [photo])
        let draft = store.draft(for: draftID)

        XCTAssertEqual(draft?.title, "Trip")
        XCTAssertEqual(draft?.slug, "trip")
        XCTAssertEqual(draft?.postDate, date)
        XCTAssertEqual(draft?.categories, ["travel"])
        XCTAssertEqual(draft?.tags, ["spring"])
        XCTAssertEqual(draft?.series, "Seoul")
        XCTAssertEqual(draft?.markdownBody, "Body text")
        XCTAssertEqual(draft?.existingFileURL, fileURL)
        XCTAssertEqual(draft?.photos.map(\.filename), ["2026-03-15-photo.jpg"])
        XCTAssertNil(draft?.lastPublished)
    }
}
