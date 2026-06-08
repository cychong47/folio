import SwiftUI

enum PostEditorDraftLifecycle {
    enum Event {
        case becameEmpty
        case publishedStateChanged
        case windowDisappeared
    }

    static func shouldRemoveDraft(isEmpty: Bool, hasPublishedRecord: Bool, event: Event) -> Bool {
        switch event {
        case .becameEmpty:
            return isEmpty && !hasPublishedRecord
        case .publishedStateChanged:
            return false
        case .windowDisappeared:
            return isEmpty || hasPublishedRecord
        }
    }
}

struct PostEditorWindowView: View {
    let draftID: UUID
    @ObservedObject var draft: PendingPost
    @EnvironmentObject private var draftStore: PostDraftStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PostEditorView()
            .environmentObject(draft)
            .onChange(of: draft.isEmpty) { isEmpty in
                guard PostEditorDraftLifecycle.shouldRemoveDraft(
                    isEmpty: isEmpty,
                    hasPublishedRecord: draft.lastPublished != nil,
                    event: .becameEmpty
                ) else { return }
                draftStore.removeDraft(draftID)
                dismiss()
            }
            .onChange(of: draft.photos) { _ in saveDraft() }
            .onChange(of: draft.title) { _ in saveDraft() }
            .onChange(of: draft.slug) { _ in saveDraft() }
            .onChange(of: draft.markdownBody) { _ in saveDraft() }
            .onChange(of: draft.categories) { _ in saveDraft() }
            .onChange(of: draft.tags) { _ in saveDraft() }
            .onChange(of: draft.series) { _ in saveDraft() }
            .onChange(of: draft.dateOverride) { _ in saveDraft() }
            .onChange(of: draft.existingFileURL) { _ in saveDraft() }
            .onChange(of: draft.lastPublished != nil) { isPublished in
                guard PostEditorDraftLifecycle.shouldRemoveDraft(
                    isEmpty: draft.isEmpty,
                    hasPublishedRecord: isPublished,
                    event: .publishedStateChanged
                ) else { return }
                draftStore.removeDraft(draftID)
            }
            .onDisappear {
                if PostEditorDraftLifecycle.shouldRemoveDraft(
                    isEmpty: draft.isEmpty,
                    hasPublishedRecord: draft.lastPublished != nil,
                    event: .windowDisappeared
                ) {
                    draftStore.removeDraft(draftID)
                } else if draft.lastPublished == nil {
                    saveDraft()
                }
            }
    }

    private func saveDraft() {
        guard !draft.isEmpty || !draft.markdownBody.isEmpty else { return }
        guard draft.lastPublished == nil else { return }
        draftStore.saveDraft(draftID)
    }
}
