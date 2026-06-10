import XCTest
@testable import Photolog

final class PostDraftStoreTests: XCTestCase {
    func testDraftPersistsAcrossStoreReload() throws {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("drafts.json")
        defer { try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent()) }

        let date = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 15,
            hour: 14,
            minute: 30
        ))!
        let photo = ExportedPhoto(
            filename: "IMG_3469.jpg",
            markdownPath: "/images/2026/03/IMG_3469.jpg",
            localURL: URL(fileURLWithPath: "/tmp/static/images/2026/03/IMG_3469.jpg"),
            exifDate: date
        )

        let store = PostDraftStore(storageURL: storageURL)
        let draftID = store.createDraft(
            markdown: "![Photo](/images/2026/03/IMG_3469.jpg)",
            date: date,
            photos: [photo]
        )
        store.draft(for: draftID)?.title = "Recovered Trip"
        store.saveDraft(draftID)

        let reloaded = PostDraftStore(storageURL: storageURL)
        let draft = reloaded.draft(for: draftID)

        XCTAssertEqual(reloaded.latestDraftID, draftID)
        XCTAssertEqual(draft?.title, "Recovered Trip")
        XCTAssertEqual(draft?.markdownBody, "![Photo](/images/2026/03/IMG_3469.jpg)")
        XCTAssertEqual(draft?.photos.map(\.filename), ["IMG_3469.jpg"])
        XCTAssertEqual(draft?.photos.first?.localURL.path, "/tmp/static/images/2026/03/IMG_3469.jpg")
        XCTAssertEqual(draft?.postDate, date)
    }

    func testRemoveDraftDeletesPersistedDraft() throws {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("drafts.json")
        defer { try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent()) }

        let store = PostDraftStore(storageURL: storageURL)
        let draftID = store.createDraft(
            markdown: "Body",
            date: Date(timeIntervalSince1970: 0),
            photos: []
        )
        XCTAssertNotNil(store.draft(for: draftID))

        store.removeDraft(draftID)

        let reloaded = PostDraftStore(storageURL: storageURL)
        XCTAssertNil(reloaded.draft(for: draftID))
        XCTAssertNil(reloaded.latestDraftID)
    }

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

    func testCreateDraftCopiesPendingPostSnapshot() {
        let store = PostDraftStore()
        let date = Calendar.current.date(from: DateComponents(
            year: 2026,
            month: 3,
            day: 15,
            hour: 10
        ))!
        let post = PendingPost()
        post.title = "Draft Trip"
        post.slug = "draft-trip"
        post.dateOverride = date
        post.markdownBody = "Body"
        post.categories = ["travel"]
        post.tags = ["spring"]
        post.series = "Seoul"
        post.photos = [
            ExportedPhoto(
                filename: "IMG_3469.jpg",
                markdownPath: "/images/2026/03/IMG_3469.jpg",
                localURL: URL(fileURLWithPath: "/tmp/static/images/2026/03/IMG_3469.jpg"),
                exifDate: date
            )
        ]

        let draftID = store.createDraft(from: post)
        post.title = "Changed After Snapshot"
        post.photos = []

        let draft = store.draft(for: draftID)
        XCTAssertEqual(draft?.title, "Draft Trip")
        XCTAssertEqual(draft?.slug, "draft-trip")
        XCTAssertEqual(draft?.postDate, date)
        XCTAssertEqual(draft?.markdownBody, "Body")
        XCTAssertEqual(draft?.categories, ["travel"])
        XCTAssertEqual(draft?.tags, ["spring"])
        XCTAssertEqual(draft?.series, "Seoul")
        XCTAssertEqual(draft?.photos.map(\.filename), ["IMG_3469.jpg"])
    }

    func testReplaceDraftOverwritesPersistedSnapshot() throws {
        let storageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("drafts.json")
        defer { try? FileManager.default.removeItem(at: storageURL.deletingLastPathComponent()) }

        let store = PostDraftStore(storageURL: storageURL)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let post = PendingPost()
        post.title = "Initial"
        post.slug = "initial"
        post.dateOverride = date
        post.markdownBody = "Initial body"
        let draftID = store.createDraft(from: post)

        post.title = "Updated"
        post.slug = "updated"
        post.markdownBody = "Updated body"
        store.replaceDraft(draftID, with: post)

        let reloaded = PostDraftStore(storageURL: storageURL)
        let draft = reloaded.draft(for: draftID)
        XCTAssertEqual(draft?.title, "Updated")
        XCTAssertEqual(draft?.slug, "updated")
        XCTAssertEqual(draft?.markdownBody, "Updated body")
        XCTAssertEqual(reloaded.latestDraftID, draftID)
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

    func testPublishedDraftStaysAvailableUntilEditorWindowCloses() {
        XCTAssertFalse(PostEditorDraftLifecycle.shouldRemoveDraft(isEmpty: false, hasPublishedRecord: true, event: .publishedStateChanged))
        XCTAssertTrue(PostEditorDraftLifecycle.shouldRemoveDraft(isEmpty: false, hasPublishedRecord: true, event: .windowDisappeared))
    }
}
