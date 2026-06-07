import SwiftUI

struct PostEditorWindowView: View {
    let draftID: UUID
    @ObservedObject var draft: PendingPost
    @EnvironmentObject private var draftStore: PostDraftStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PostEditorView()
            .environmentObject(draft)
            .onChange(of: draft.isEmpty) { isEmpty in
                guard isEmpty, draft.lastPublished == nil else { return }
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
                guard isPublished else { return }
                draftStore.removeDraft(draftID)
            }
            .onDisappear {
                if draft.isEmpty {
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
