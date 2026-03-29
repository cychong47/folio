import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var pendingPost: PendingPost
    @EnvironmentObject var settings: AppSettings
    @State private var isDragTargeted = false
    @State private var importTotal: Int = 0
    @State private var importCompleted: Int = 0

    private var isImporting: Bool { importTotal > 0 }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if pendingPost.isEmpty {
                WelcomeView(isDragTargeted: isDragTargeted)
            } else {
                PostEditorView()
            }

            DropZone(
                isDragTargeted: $isDragTargeted,
                onImportStarted: { total in
                    importTotal = total
                    importCompleted = 0
                },
                onProgress: { completed, total in
                    importCompleted = completed
                    importTotal = total
                },
                onDrop: handleDroppedPhotos
            )

            if isImporting {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView(value: Double(importCompleted), total: Double(importTotal))
                        .progressViewStyle(.linear)
                        .frame(width: 160)
                    Text("Importing \(importCompleted) / \(importTotal)")
                        .foregroundStyle(.white)
                        .font(.headline)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func handleDroppedPhotos(_ photos: [ExportedPhoto]) {
        importTotal = 0
        importCompleted = 0
        guard !photos.isEmpty else { return }

        let existingFilenames = Set(pendingPost.photos.map(\.filename))
        let newPhotos = photos.filter { !existingFilenames.contains($0.filename) }
        guard !newPhotos.isEmpty else { return }

        pendingPost.lastPublished = nil
        pendingPost.photos.append(contentsOf: newPhotos)

        let allPhotos = pendingPost.photos
        let date = allPhotos.first?.exifDate ?? Date()

        if pendingPost.title.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            pendingPost.title = f.string(from: date)
            pendingPost.slug = SlugGenerator.slugify(pendingPost.title)
        }

        pendingPost.markdownBody = MarkdownGenerator.initialMarkdown(
            title: pendingPost.title, date: date, photos: allPhotos, categories: pendingPost.categories)
    }
}

// MARK: - NSViewRepresentable wrapper

struct DropZone: NSViewRepresentable {
    @Binding var isDragTargeted: Bool
    let onImportStarted: (Int) -> Void
    let onProgress: (Int, Int) -> Void
    let onDrop: ([ExportedPhoto]) -> Void

    func makeNSView(context: Context) -> DropTargetView {
        let view = DropTargetView()
        view.onFilesDropped = onDrop
        view.onImportStarted = onImportStarted
        view.onProgress = onProgress
        view.onDragEntered = { isDragTargeted = true }
        view.onDragExited  = { isDragTargeted = false }
        return view
    }

    func updateNSView(_ nsView: DropTargetView, context: Context) {
        nsView.onFilesDropped = onDrop
        nsView.onImportStarted = onImportStarted
        nsView.onProgress = onProgress
    }
}
