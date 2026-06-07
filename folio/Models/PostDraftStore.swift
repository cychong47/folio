import Foundation

final class PostDraftStore: ObservableObject {
    @Published private var drafts: [UUID: PendingPost] = [:]
    private var updatedAt: [UUID: Date] = [:]
    private let storageURL: URL

    var latestDraftID: UUID? {
        updatedAt.max { lhs, rhs in lhs.value < rhs.value }?.key
    }

    var autosavedDraftCount: Int {
        drafts.count
    }

    convenience init() {
        self.init(storageURL: Self.defaultStorageURL())
    }

    init(storageURL: URL) {
        self.storageURL = storageURL
        load()
    }

    @discardableResult
    func createDraft(markdown: String, date: Date, photos: [ExportedPhoto]) -> UUID {
        let draft = PendingPost()
        draft.photos = photos
        draft.markdownBody = markdown
        draft.dateOverride = date

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        draft.slug = formatter.string(from: date)

        let id = UUID()
        drafts[id] = draft
        updatedAt[id] = Date()
        persist()
        return id
    }

    @discardableResult
    func createDraft(from summary: PostSummary, photos: [ExportedPhoto]) -> UUID {
        let draft = PendingPost()
        draft.photos = photos
        draft.title = summary.title
        draft.slug = summary.slug
        draft.dateOverride = summary.date
        draft.categories = summary.categories
        draft.tags = summary.tags
        draft.series = summary.series
        draft.markdownBody = summary.bodyText
        draft.existingFileURL = summary.fileURL
        draft.lastPublished = nil

        let id = UUID()
        drafts[id] = draft
        updatedAt[id] = Date()
        persist()
        return id
    }

    func draft(for id: UUID) -> PendingPost? {
        drafts[id]
    }

    func saveDraft(_ id: UUID) {
        guard drafts[id] != nil else { return }
        updatedAt[id] = Date()
        persist()
    }

    func removeDraft(_ id: UUID) {
        drafts[id] = nil
        updatedAt[id] = nil
        persist()
    }

    private static func defaultStorageURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Photolog", isDirectory: true)
            .appendingPathComponent("post-drafts.json")
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let records = try? JSONDecoder().decode([StoredDraft].self, from: data) else {
            return
        }
        drafts = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.snapshot.pendingPost()) })
        updatedAt = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.updatedAt) })
    }

    private func persist() {
        let records = drafts.compactMap { id, post -> StoredDraft? in
            guard !post.isEmpty || !post.markdownBody.isEmpty else { return nil }
            return StoredDraft(
                id: id,
                updatedAt: updatedAt[id] ?? Date(),
                snapshot: PendingPostSnapshot(post: post)
            )
        }
        do {
            try FileManager.default.createDirectory(
                at: storageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records.sorted { $0.updatedAt > $1.updatedAt })
            try data.write(to: storageURL, options: .atomic)
        } catch {
            NSLog("[Photolog] Failed to persist post drafts: \(error)")
        }
    }
}

private struct StoredDraft: Codable {
    let id: UUID
    let updatedAt: Date
    let snapshot: PendingPostSnapshot
}

private struct PendingPostSnapshot: Codable {
    let photos: [ExportedPhoto]
    let title: String
    let slug: String
    let markdownBody: String
    let categories: [String]
    let tags: [String]
    let series: String
    let dateOverride: Date?
    let existingFileURL: URL?

    init(post: PendingPost) {
        self.photos = post.photos
        self.title = post.title
        self.slug = post.slug
        self.markdownBody = post.markdownBody
        self.categories = post.categories
        self.tags = post.tags
        self.series = post.series
        self.dateOverride = post.dateOverride
        self.existingFileURL = post.existingFileURL
    }

    func pendingPost() -> PendingPost {
        let post = PendingPost()
        post.photos = photos
        post.title = title
        post.slug = slug
        post.markdownBody = markdownBody
        post.categories = categories
        post.tags = tags
        post.series = series
        post.dateOverride = dateOverride
        post.existingFileURL = existingFileURL
        post.lastPublished = nil
        return post
    }
}
