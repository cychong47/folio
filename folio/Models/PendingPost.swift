import Foundation

struct ExportedPhoto: Identifiable, Codable {
    var id: String { filename }
    let filename: String        // e.g. "2026-03-05-photo.jpg"
    let markdownPath: String    // e.g. "/images/2026-03-05-photo.jpg"
    let localURL: URL           // file URL in App Group /pending/
    let exifDate: Date
    var isVideo: Bool = false
}

struct PendingPostMetadata: Codable {
    let photos: [PhotoMetadata]

    struct PhotoMetadata: Codable {
        let filename: String
        let markdownPath: String
        let localPath: String   // relative path inside App Group container
        let exifDate: Date
    }
}

struct PublishedRecord {
    let markdownURL: URL
    let imageURLs: [URL]
    let title: String
}

class PendingPost: ObservableObject {
    @Published var photos: [ExportedPhoto] = []
    @Published var title: String = ""
    @Published var slug: String = ""
    @Published var markdownBody: String = ""
    @Published var categories: [String] = []
    @Published var tags: [String] = []
    @Published var series: String = ""
    @Published var dateOverride: Date? = nil
    @Published var lastPublished: PublishedRecord? = nil
    /// Set when re-editing an existing post; save() will overwrite this URL directly.
    @Published var existingFileURL: URL? = nil

    var isEmpty: Bool { photos.isEmpty && title.isEmpty && existingFileURL == nil }

    /// The effective post date: user override if set, otherwise first photo's EXIF date, otherwise today.
    var postDate: Date { dateOverride ?? photos.first?.exifDate ?? Date() }

    func clear() {
        photos = []
        title = ""
        slug = ""
        markdownBody = ""
        categories = []
        tags = []
        series = ""
        dateOverride = nil
        existingFileURL = nil
        // lastPublished intentionally preserved so the user can still cancel
    }
}
