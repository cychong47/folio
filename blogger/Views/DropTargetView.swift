import AppKit
import UniformTypeIdentifiers

// NSView subclass that properly handles NSFilePromiseReceiver (Photos.app drag)
// and plain file URL drops (Finder drag).
class DropTargetView: NSView {
    var onFilesDropped: (([ExportedPhoto]) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onImportStarted: (() -> Void)?

    // Single serial queue — prevents concurrent NSPasteboard access crash (macOS 13)
    private let promiseQueue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "com.blogger.filepromise"
        return q
    }()

    private var stagingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Blogger/pending", isDirectory: true)
    }

    private var imageURLPrefix: String {
        UserDefaults(suiteName: "group.com.blogger.app")?.string(forKey: "imageURLPrefix") ?? "/images"
    }

    private var staticImagesSubpath: String {
        UserDefaults(suiteName: "group.com.blogger.app")?.string(forKey: "staticImagesSubpath") ?? ""
    }

    private func markdownPath(for filename: String, date: Date) -> String {
        let prefix = imageURLPrefix.hasSuffix("/") ? imageURLPrefix : imageURLPrefix + "/"
        let sub = AppSettings.resolveSubpath(staticImagesSubpath, for: date)
        if sub.isEmpty {
            return "\(prefix)\(filename)"
        }
        let subSlashed = sub.hasSuffix("/") ? sub : sub + "/"
        return "\(prefix)\(subSlashed)\(filename)"
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes
            .map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes(promiseTypes + [.fileURL])
    }

    // Pass all normal mouse events through to SwiftUI views below.
    // Drag events are still received because they use registerForDraggedTypes,
    // which is independent of hit-testing.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onDragExited?()
        let stagingDir = stagingDirectory
        try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let pasteboard = sender.draggingPasteboard
        let promiseTypeStrings = NSFilePromiseReceiver.readableDraggedTypes

        // Check if any item is a file promise (Photos.app)
        let hasPromises = pasteboard.pasteboardItems?.contains { item in
            item.types.contains { promiseTypeStrings.contains($0.rawValue) }
        } ?? false

        onImportStarted?()

        if hasPromises {
            let receivers = (pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self],
                                                    options: nil) as? [NSFilePromiseReceiver]) ?? []
            receiveFilePromises(receivers, stagingDir: stagingDir)
        } else {
            // Plain file URLs from Finder
            let urls = (pasteboard.readObjects(forClasses: [NSURL.self],
                                               options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
            let imageExts = Set(["jpg","jpeg","png","heic","heif","tiff","tif","gif","webp","raw"])
            processFileURLs(urls.filter { imageExts.contains($0.pathExtension.lowercased()) },
                            stagingDir: stagingDir)
        }
        return true
    }

    // MARK: - File promise receiving

    private func receiveFilePromises(_ receivers: [NSFilePromiseReceiver], stagingDir: URL) {
        let group = DispatchGroup()
        var photos: [ExportedPhoto] = []
        let lock = NSLock()

        for receiver in receivers {
            group.enter()
            receiver.receivePromisedFiles(atDestination: stagingDir, options: [:],
                                          operationQueue: promiseQueue) { url, error in
                defer { group.leave() }
                guard error == nil else { return }

                let exifDate = PhotoExporter.readEXIFDate(from: url) ?? Date()
                let filename = PhotoExporter.exportedFilename(
                    originalName: url.lastPathComponent, date: exifDate)
                let dest = stagingDir.appendingPathComponent(filename)

                if url.path != dest.path {
                    try? FileManager.default.moveItem(at: url, to: dest)
                }

                let photo = ExportedPhoto(filename: filename,
                                          markdownPath: markdownPath(for: filename, date: exifDate),
                                          localURL: dest, exifDate: exifDate)
                lock.lock(); photos.append(photo); lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.onFilesDropped?(photos.sorted { $0.exifDate < $1.exifDate })
        }
    }

    // MARK: - Plain file URL handling

    private func processFileURLs(_ urls: [URL], stagingDir: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var photos: [ExportedPhoto] = []
            for url in urls {
                let exifDate = PhotoExporter.readEXIFDate(from: url) ?? Date()
                let filename = PhotoExporter.exportedFilename(
                    originalName: url.lastPathComponent, date: exifDate)
                let dest = stagingDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.copyItem(at: url, to: dest)
                let photo = ExportedPhoto(filename: filename,
                                          markdownPath: markdownPath(for: filename, date: exifDate),
                                          localURL: dest, exifDate: exifDate)
                photos.append(photo)
            }
            DispatchQueue.main.async {
                self?.onFilesDropped?(photos.sorted { $0.exifDate < $1.exifDate })
            }
        }
    }
}
