import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var pendingPost: PendingPost
    @EnvironmentObject var settings: AppSettings
    @State private var isDragTargeted = false

    var body: some View {
        ZStack {
            if pendingPost.isEmpty {
                WelcomeView(isDragTargeted: isDragTargeted)
            } else {
                PostEditorView()
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDragTargeted) { providers in
            loadDroppedPhotos(providers)
            return true
        }
    }

    private func loadDroppedPhotos(_ providers: [NSItemProvider]) {
        // Capture settings values on the main thread before going async
        let imageURLPrefix = settings.imageURLPrefix

        let group = DispatchGroup()
        var photos: [ExportedPhoto] = []
        let lock = NSLock()

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            group.enter()

            // On macOS, Finder drag-and-drop delivers URLs as NSURL, not Data
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                defer { group.leave() }

                // Handle both NSURL and Data representations
                let fileURL: URL?
                if let url = item as? URL {
                    fileURL = url
                } else if let data = item as? Data {
                    fileURL = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    fileURL = nil
                }

                guard let url = fileURL else { return }

                // Only process image files
                let ext = url.pathExtension.lowercased()
                let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "webp", "raw"]
                guard imageExtensions.contains(ext) else { return }

                guard let imageData = try? Data(contentsOf: url) else { return }

                let exifDate = PhotoExporter.readEXIFDate(from: imageData) ?? Date()
                let filename = PhotoExporter.exportedFilename(
                    originalName: url.lastPathComponent, date: exifDate)

                let prefix = imageURLPrefix.hasSuffix("/") ? imageURLPrefix : imageURLPrefix + "/"
                let markdownPath = "\(prefix)\(filename)"

                let photo = ExportedPhoto(
                    filename: filename,
                    markdownPath: markdownPath,
                    localURL: url,
                    exifDate: exifDate
                )
                lock.lock()
                photos.append(photo)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            guard !photos.isEmpty else { return }
            let sorted = photos.sorted { $0.exifDate < $1.exifDate }
            pendingPost.photos.append(contentsOf: sorted)

            let allPhotos = pendingPost.photos
            let date = allPhotos.first?.exifDate ?? Date()

            if pendingPost.title.isEmpty {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                pendingPost.title = f.string(from: date)
                pendingPost.slug = SlugGenerator.slugify(pendingPost.title)
            }

            pendingPost.markdownBody = MarkdownGenerator.initialMarkdown(
                title: pendingPost.title,
                date: date,
                photos: allPhotos
            )
        }
    }
}
