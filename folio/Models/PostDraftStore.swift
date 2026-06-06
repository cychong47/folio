import Foundation

final class PostDraftStore: ObservableObject {
    @Published private var drafts: [UUID: PendingPost] = [:]

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
        return id
    }

    func draft(for id: UUID) -> PendingPost? {
        drafts[id]
    }

    func removeDraft(_ id: UUID) {
        drafts[id] = nil
    }
}
