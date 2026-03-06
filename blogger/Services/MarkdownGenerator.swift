import Foundation

enum MarkdownGenerator {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func frontmatter(title: String, date: Date) -> String {
        let dateStr = dateFormatter.string(from: date)
        return """
        ---
        title: "\(title)"
        date: "\(dateStr)"
        draft: false
        categories: []
        tags: []
        ---
        """
    }

    static func imageReference(markdownPath: String) -> String {
        "![](\(markdownPath))"
    }

    static func initialMarkdown(title: String, date: Date, photos: [ExportedPhoto]) -> String {
        var parts: [String] = [frontmatter(title: title, date: date), ""]
        let imageRefs = photos.map { imageReference(markdownPath: $0.markdownPath) }
        parts.append(contentsOf: imageRefs)
        parts.append("")
        parts.append("")
        return parts.joined(separator: "\n")
    }

    static func write(content: String, slug: String, date: Date, settings: AppSettings) throws -> URL {
        let subpath = AppSettings.resolveSubpath(settings.contentSubpath, for: date)
        var destDir = URL(fileURLWithPath: settings.contentPath)
        if !subpath.isEmpty {
            destDir = destDir.appendingPathComponent(subpath, isDirectory: true)
        }

        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let fileURL = destDir.appendingPathComponent("\(slug).md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
