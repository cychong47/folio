import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var pendingPost: PendingPost
    @EnvironmentObject var settings: AppSettings
    @State private var isDragTargeted = false
    @State private var importTotal: Int = 0
    @State private var importCompleted: Int = 0
    @State private var browsing = false

    private var isImporting: Bool { importTotal > 0 }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if !pendingPost.isEmpty {
                PostEditorView()
            } else if browsing {
                PostListView(
                    onBack: { browsing = false },
                    onSelect: { summary in
                        loadPost(summary)
                        browsing = false
                    }
                )
            } else {
                WelcomeView(isDragTargeted: isDragTargeted, onBrowse: { browsing = true })
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

    private func loadPost(_ summary: PostSummary) {
        pendingPost.clear()
        pendingPost.lastPublished = nil   // don't carry previous session's record into a re-edit
        pendingPost.title = summary.title
        pendingPost.slug = summary.slug
        pendingPost.dateOverride = summary.date
        pendingPost.categories = summary.categories
        pendingPost.tags = summary.tags
        pendingPost.series = summary.series
        pendingPost.markdownBody = summary.bodyText
        pendingPost.existingFileURL = summary.fileURL
        pendingPost.photos = resolvedPhotos(from: summary.bodyText, postDate: summary.date)
    }

    /// Parses image references from markdown body and resolves them to ExportedPhoto instances
    /// pointing at files already on disk in staticImagesPath.
    private func resolvedPhotos(from body: String, postDate: Date) -> [ExportedPhoto] {
        let pattern = #"!\[.*?\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let staticBase = URL(fileURLWithPath: settings.staticImagesPath)
        let prefix = settings.imageURLPrefix

        var photos: [ExportedPhoto] = []
        var seen = Set<String>()
        for line in body.components(separatedBy: "\n") {
            let ns = line as NSString
            let matches = regex.matches(in: line, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard let range = Range(match.range(at: 1), in: line) else { continue }
                let markdownPath = String(line[range])
                guard seen.insert(markdownPath).inserted else { continue }

                // Strip imageURLPrefix to get path relative to staticImagesPath
                let stripped: String
                let normalizedPrefix = prefix.hasSuffix("/") ? String(prefix.dropLast()) : prefix
                if markdownPath.hasPrefix(normalizedPrefix + "/") {
                    stripped = String(markdownPath.dropFirst(normalizedPrefix.count + 1))
                } else if markdownPath.hasPrefix(normalizedPrefix) {
                    stripped = String(markdownPath.dropFirst(normalizedPrefix.count))
                } else {
                    stripped = (markdownPath as NSString).lastPathComponent
                }

                let localURL = staticBase.appendingPathComponent(stripped)
                guard FileManager.default.fileExists(atPath: localURL.path) else { continue }

                let filename = localURL.lastPathComponent
                let exifDate = PhotoExporter.readEXIFDate(from: localURL) ?? postDate
                photos.append(ExportedPhoto(
                    filename: filename,
                    markdownPath: markdownPath,
                    localURL: localURL,
                    exifDate: exifDate
                ))
            }
        }
        return photos
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

        if pendingPost.slug.isEmpty {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            pendingPost.slug = f.string(from: date)
        }

        if pendingPost.markdownBody.isEmpty {
            // First drop on the welcome screen — generate the full initial body.
            pendingPost.markdownBody = MarkdownGenerator.initialBody(photos: allPhotos)
        } else {
            // Editor already open — append refs for new photos only to preserve edits.
            for photo in newPhotos {
                pendingPost.markdownBody = MarkdownGenerator.appendPhotoRef(
                    photo: photo, to: pendingPost.markdownBody)
            }
        }
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
