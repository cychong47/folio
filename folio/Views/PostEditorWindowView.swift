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
            .onDisappear {
                if draft.isEmpty {
                    draftStore.removeDraft(draftID)
                }
            }
    }
}
