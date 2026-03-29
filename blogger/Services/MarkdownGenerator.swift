import Foundation

enum MarkdownGenerator {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // Quote a YAML scalar only when the value would be ambiguous or invalid as a plain scalar.
    // Block context (e.g. `title: value`).
    static func yamlScalar(_ s: String) -> String {
        let needsQuoting = s.isEmpty
            || s.contains(": ") || s.hasSuffix(":")
            || s.contains(" #")
            || s.first.map({ "\"'|>{[&*!%@`".contains($0) }) ?? false
        return needsQuoting ? "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"" : s
    }

    // Flow sequence context (e.g. inside `[…]`): additionally forbid flow-indicator chars.
    static func yamlFlowScalar(_ s: String) -> String {
        let needsQuoting = s.isEmpty
            || s.contains(",") || s.contains("[") || s.contains("]")
            || s.contains("{") || s.contains("}")
            || s.contains(": ") || s.hasSuffix(":")
            || s.contains(" #")
            || s.first.map({ "\"'|>&*!%@`".contains($0) }) ?? false
        return needsQuoting ? "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"" : s
    }

    static func frontmatter(title: String, date: Date, categories: [String] = [], tags: [String] = [], series: String = "") -> String {
        let dateStr = dateFormatter.string(from: date)
        let catsStr = categories.map { yamlFlowScalar($0) }.joined(separator: ", ")
        let tagsStr = tags.map { yamlFlowScalar($0) }.joined(separator: ", ")
        var lines = [
            "---",
            "title: \(yamlScalar(title))",
            "date: \(dateStr)",
            "draft: false",
            "categories: [\(catsStr)]",
            "tags: [\(tagsStr)]",
        ]
        if !series.isEmpty {
            lines.append("series: [\(yamlFlowScalar(series))]")
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    static func imageReference(markdownPath: String) -> String {
        "![](\(markdownPath))"
    }

    /// Returns only the body content (image references + blank lines) — no frontmatter.
    /// Frontmatter is composed from model fields at publish time.
    static func initialBody(photos: [ExportedPhoto]) -> String {
        var parts: [String] = [""]
        let imageRefs = photos.map { imageReference(markdownPath: $0.markdownPath) }
        parts.append(contentsOf: imageRefs)
        parts.append("")
        parts.append("")
        return parts.joined(separator: "\n")
    }

    static func write(content: String, filename: String, date: Date, settings: AppSettings) throws -> URL {
        let subpath = AppSettings.resolveSubpath(settings.contentSubpath, for: date)
        var destDir = URL(fileURLWithPath: settings.contentPath)
        if !subpath.isEmpty {
            destDir = destDir.appendingPathComponent(subpath, isDirectory: true)
        }

        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)

        let fileURL = destDir.appendingPathComponent("\(filename).md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
