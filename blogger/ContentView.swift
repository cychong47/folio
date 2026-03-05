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

    // Staging directory for images dragged from Photos.app (no App Group needed)
    private var stagingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Blogger/pending", isDirectory: true)
    }

    private func loadDroppedPhotos(_ providers: [NSItemProvider]) {
        let imageURLPrefix = settings.imageURLPrefix  // capture on main thread
        try? FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        let stagingDir = stagingDirectory

        let group = DispatchGroup()
        var photos: [ExportedPhoto] = []
        let lock = NSLock()

        for provider in providers {
            // --- Case 1: File URL (drag from Finder) ---
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }

                    let fileURL: URL?
                    if let url = item as? URL {
                        fileURL = url
                    } else if let data = item as? Data {
                        fileURL = URL(dataRepresentation: data, relativeTo: nil)
                    } else {
                        fileURL = nil
                    }
                    guard let url = fileURL else { return }

                    let ext = url.pathExtension.lowercased()
                    guard ["jpg","jpeg","png","heic","heif","tiff","tif","gif","webp"].contains(ext) else { return }
                    guard let imageData = try? Data(contentsOf: url) else { return }

                    if let photo = makePhoto(from: imageData, originalName: url.lastPathComponent,
                                             stagingDir: stagingDir, prefix: imageURLPrefix) {
                        lock.lock(); photos.append(photo); lock.unlock()
                    }
                }

            // --- Case 2: Image data (drag from Photos.app) ---
            } else {
                // Try common image type identifiers in priority order
                let imageTypes = [UTType.jpeg.identifier, UTType.heic.identifier,
                                  UTType.png.identifier, UTType.tiff.identifier,
                                  UTType.image.identifier]
                guard let typeID = imageTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                    continue
                }

                group.enter()
                provider.loadDataRepresentation(forTypeIdentifier: typeID) { data, _ in
                    defer { group.leave() }
                    guard let data else { return }

                    let ext = UTType(typeID)?.preferredFilenameExtension ?? "jpg"
                    let originalName = "photo.\(ext)"

                    if let photo = makePhoto(from: imageData(data), originalName: originalName,
                                             stagingDir: stagingDir, prefix: imageURLPrefix) {
                        lock.lock(); photos.append(photo); lock.unlock()
                    }
                }
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

    // Inline helper to avoid shadowing the parameter name
    private func imageData(_ data: Data) -> Data { data }

    private func makePhoto(from data: Data, originalName: String,
                           stagingDir: URL, prefix: String) -> ExportedPhoto? {
        let exifDate = PhotoExporter.readEXIFDate(from: data) ?? Date()
        let filename = PhotoExporter.exportedFilename(originalName: originalName, date: exifDate)

        let dest = stagingDir.appendingPathComponent(filename)
        // Avoid overwriting if same filename already exists
        if !FileManager.default.fileExists(atPath: dest.path) {
            guard (try? data.write(to: dest, options: .atomic)) != nil else { return nil }
        }

        let slash = prefix.hasSuffix("/") ? prefix : prefix + "/"
        return ExportedPhoto(filename: filename, markdownPath: "\(slash)\(filename)",
                             localURL: dest, exifDate: exifDate)
    }
}
