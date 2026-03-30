import Cocoa
import UniformTypeIdentifiers
import ImageIO

class ShareViewController: NSViewController {
    override var nibName: NSNib.Name? { return NSNib.Name("ShareViewController") }

    private let appGroupID = "group.com.blogger.app"
    private let urlScheme = "blogger://new-post"

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        processItemsAndOpenApp()
    }

    private func processItemsAndOpenApp() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments, !attachments.isEmpty else {
            completeRequest()
            return
        }

        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID) else {
            completeRequest()
            return
        }

        let pendingDir = container.appendingPathComponent("pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: pendingDir, withIntermediateDirectories: true)

        let group = DispatchGroup()
        var photoMeta: [PendingPostMetadata.PhotoMetadata] = []
        let lock = NSLock()

        let imageTypes: [UTType] = [.jpeg, .png, .heic, .tiff, .rawImage, .image]
        let typeIdentifiers = imageTypes.map(\.identifier)

        for provider in attachments {
            // Find a matching type
            guard let typeID = typeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
                continue
            }

            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: typeID) { [weak self] data, error in
                defer { group.leave() }
                guard let self, let data else { return }

                let ext = UTType(typeID)?.preferredFilenameExtension ?? "jpg"
                let originalName = "photo.\(ext)"
                let exifDate = PhotoExporter.readEXIFDate(from: data) ?? Date()
                let filename = PhotoExporter.exportedFilename(originalName: originalName, date: exifDate)

                let destURL = pendingDir.appendingPathComponent(filename)
                do {
                    try data.write(to: destURL, options: .atomic)

                    // Read image URL prefix from shared defaults
                    let defaults = UserDefaults(suiteName: self.appGroupID)
                    let prefix = defaults?.string(forKey: "imageURLPrefix") ?? "/images"
                    let prefixSlashed = prefix.hasSuffix("/") ? prefix : prefix + "/"
                    let markdownPath = "\(prefixSlashed)\(filename)"

                    let meta = PendingPostMetadata.PhotoMetadata(
                        filename: filename,
                        markdownPath: markdownPath,
                        localPath: filename,
                        exifDate: exifDate
                    )
                    lock.lock()
                    photoMeta.append(meta)
                    lock.unlock()
                } catch {
                    print("[ShareExtension] Failed to write \(filename): \(error)")
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            // Sort by date
            let sorted = photoMeta.sorted { $0.exifDate < $1.exifDate }
            let metadata = PendingPostMetadata(photos: sorted)
            let metaURL = container.appendingPathComponent("pending.json")

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(metadata) {
                try? data.write(to: metaURL, options: .atomic)
            }

            // Open main app
            if let url = URL(string: self.urlScheme) {
                NSWorkspace.shared.open(url)
            }

            self.completeRequest()
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}

// MARK: - Re-use shared types in extension (inline copies since Shared/ target isn't linked directly)

// PhotoExporter inline subset (EXIF + filename)
private enum PhotoExporter {
    static func exportedFilename(originalName: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        let nameOnly = (originalName as NSString).deletingPathExtension
        let ext = (originalName as NSString).pathExtension
        let sanitised = nameOnly.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
        return ext.isEmpty ? "\(dateStr)-\(sanitised)" : "\(dateStr)-\(sanitised).\(ext)"
    }

    static func readEXIFDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.date(from: dateString)
    }
}

// PendingPostMetadata inline copy
struct PendingPostMetadata: Codable {
    let photos: [PhotoMetadata]

    struct PhotoMetadata: Codable {
        let filename: String
        let markdownPath: String
        let localPath: String
        let exifDate: Date
    }
}
