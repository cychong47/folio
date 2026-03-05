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
        .onDrop(of: [UTType.image, UTType.fileURL], isTargeted: $isDragTargeted) { providers in
            loadDroppedPhotos(providers)
            return true
        }
    }

    private func loadDroppedPhotos(_ providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var photos: [ExportedPhoto] = []
        let lock = NSLock()

        for provider in providers {
            guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { continue }
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                let uti = UTType(filenameExtension: url.pathExtension)
                guard uti?.conforms(to: .image) == true else { return }
                guard let imageData = try? Data(contentsOf: url) else { return }

                let exifDate = PhotoExporter.readEXIFDate(from: imageData) ?? Date()
                let filename = PhotoExporter.exportedFilename(originalName: url.lastPathComponent, date: exifDate)
                let markdownPath = PhotoExporter.markdownImagePath(filename: filename, settings: settings)

                // Copy into pending directory
                if let pendingDir = SharedContainerService.pendingDirectoryURL {
                    try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)
                    let dest = pendingDir.appendingPathComponent(filename)
                    try? FileManager.default.copyItem(at: url, to: dest)

                    let photo = ExportedPhoto(filename: filename, markdownPath: markdownPath,
                                              localURL: dest, exifDate: exifDate)
                    lock.lock()
                    photos.append(photo)
                    lock.unlock()
                }
            }
        }

        group.notify(queue: .main) {
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
