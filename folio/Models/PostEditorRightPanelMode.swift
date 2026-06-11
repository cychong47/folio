enum PostEditorRightPanelMode: String, CaseIterable, Equatable, Identifiable {
    case preview
    case revise

    static let defaultMode: PostEditorRightPanelMode = .preview

    var id: String { rawValue }

    var title: String {
        switch self {
        case .preview: return "Preview"
        case .revise: return "Revise"
        }
    }
}
