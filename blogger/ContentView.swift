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
        .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: $isDragTargeted) { providers in
            loadDroppedPhotos(providers)
            return true
        }
    }

    private var stagingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Blogger/pending", isDirectory: true)
    }

    private func loadDroppedPhotos(_ providers: [NSItemProvider]) {
        let imageURLPrefix = settings.imageURLPrefix   // capture on main thread
        let stagingDir = stagingDirectory
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let group = DispatchGroup()
        var photos: [ExportedPhoto] = []
        let lock = NSLock()

        // Image type identifiers to try, in priority order
        let imageTypeIDs = [UTType.jpeg.identifier, UTType.heic.identifier,
                            UTType.png.identifier,  UTType.tiff.identifier,
                            UTType.image.identifier]

        for provider in providers {
            // Prefer file URL (Finder drag); fall back to image data (Photos.app drag)
            let useFileURL = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            let typeID = useFileURL
                ? UTType.fileURL.identifier
                : imageTypeIDs.first { provider.hasItemConformingToTypeIdentifier($0) }

            guard let typeID else { continue }

            group.enter()

            // loadFileRepresentation gives a temp file URL — avoids loading full image into RAM
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { tempURL, error in
                defer { group.leave() }
                guard let tempURL else { return }

                // Read EXIF from URL (only metadata, not full pixels)
                let exifDate = PhotoExporter.readEXIFDate(from: tempURL) ?? Date()
                let filename = PhotoExporter.exportedFilename(
                    originalName: tempURL.lastPathComponent, date: exifDate)

                // Copy to staging dir before temp file is deleted
                let dest = stagingDir.appendingPathComponent(filename)
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: tempURL, to: dest)
                } catch {
                    return
                }

                let slash = imageURLPrefix.hasSuffix("/") ? imageURLPrefix : imageURLPrefix + "/"
                let photo = ExportedPhoto(
                    filename: filename,
                    markdownPath: "\(slash)\(filename)",
                    localURL: dest,
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
                title: pendingPost.title, date: date, photos: allPhotos)
        }
    }
}
