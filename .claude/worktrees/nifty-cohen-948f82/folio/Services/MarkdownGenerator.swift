import Foundation

enum MarkdownGenerator {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
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

    static func frontmatter(title: String, date: Date, categories: [String] = [], tags: [String] = [], series: String = "", customFields: [FrontmatterField] = []) -> String {
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
        for field in customFields {
            let k = field.key.trimmingCharacters(in: .whitespaces)
            guard !k.isEmpty else { continue }
            lines.append("\(k): \(yamlScalar(field.value))")
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    static func imageReference(markdownPath: String) -> String {
        "![](\(markdownPath))"
    }

    static func videoReference(markdownPath: String) -> String {
        "{{< video library=\"1\" src=\"\(markdownPath)\" controls=\"yes\" >}}"
    }

    // MARK: - Photo ref helpers

    /// Removes the line referencing `photo` from `body`.
    /// Handles image syntax `![any alt](path optional-title)` and Hugo video shortcodes.
    /// No-op if the reference is not found.
    static func removePhotoRef(photo: ExportedPhoto, from body: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: photo.markdownPath)
        let pattern: String
        if photo.isVideo {
            // {{< video … src="path" … >}}
            pattern = #"\{\{< video [^>]*src=""# + escaped + #""[^>]* >\}\}"#
        } else {
            // ![any alt](path optional-title)
            pattern = #"!\[.*?\]\("# + escaped + #"(?:\s[^)]*)?\)"#
        }
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return body }
        let lines = body.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            let range = NSRange(line.startIndex..., in: line)
            return regex.firstMatch(in: line, range: range) == nil
        }
        return filtered.joined(separator: "\n")
    }

    /// Appends the correct ref for `photo` (image or Hugo video shortcode) after the
    /// last existing ref in `body`, or at the end if no refs are present.
    static func appendPhotoRef(photo: ExportedPhoto, to body: String) -> String {
        let ref = photo.isVideo
            ? videoReference(markdownPath: photo.markdownPath)
            : imageReference(markdownPath: photo.markdownPath)
        let refPattern = #"(?:!\[.*?\]\([^)]+\)|\{\{< video [^>]*src="[^"]+"[^>]* >\}\})"#
        guard let regex = try? NSRegularExpression(pattern: refPattern) else {
            return body + "\n" + ref
        }
        var lines = body.components(separatedBy: "\n")
        var lastRefIndex = -1
        for (i, line) in lines.enumerated() {
            let range = NSRange(line.startIndex..., in: line)
            if regex.firstMatch(in: line, range: range) != nil { lastRefIndex = i }
        }
        if lastRefIndex >= 0 {
            lines.insert(ref, at: lastRefIndex + 1)
        } else {
            if lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == false {
                lines.append("")
            }
            lines.append(ref)
        }
        return lines.joined(separator: "\n")
    }

    /// Reorders the ref lines in `body` to match the order of `orderedPhotos`.
    /// Non-ref lines are left in place; only the ref content is swapped.
    static func reorderPhotoRefs(orderedPhotos: [ExportedPhoto], in body: String) -> String {
        let refPattern = #"(?:!\[.*?\]\([^)]+\)|\{\{< video [^>]*src="[^"]+"[^>]* >\}\})"#
        guard let regex = try? NSRegularExpression(pattern: refPattern) else { return body }
        var lines = body.components(separatedBy: "\n")
        let refIndices = lines.indices.filter { i in
            let range = NSRange(lines[i].startIndex..., in: lines[i])
            return regex.firstMatch(in: lines[i], range: range) != nil
        }
        guard !refIndices.isEmpty else { return body }
        let newRefs = orderedPhotos.map { photo in
            photo.isVideo
                ? videoReference(markdownPath: photo.markdownPath)
                : imageReference(markdownPath: photo.markdownPath)
        }
        for (slot, idx) in refIndices.enumerated() where slot < newRefs.count {
            lines[idx] = newRefs[slot]
        }
        return lines.joined(separator: "\n")
    }

    /// Returns the set of all markdown paths referenced in `body`
    /// (both image `![]()` and Hugo video shortcode `src=`).
    static func referencedPaths(in body: String) -> Set<String> {
        let imagePattern = #"!\[.*?\]\(([^)\s]+)"#
        let videoPattern = #"\{\{< video [^>]*src="([^"]+)"[^>]* >\}\}"#
        var paths = Set<String>()
        for pattern in [imagePattern, videoPattern] {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = body as NSString
            let matches = regex.matches(in: body, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                if let range = Range(match.range(at: 1), in: body) {
                    paths.insert(String(body[range]))
                }
            }
        }
        return paths
    }

    /// Returns only the body content (image/video references + blank lines) — no frontmatter.
    /// Frontmatter is composed from model fields at publish time.
    static func initialBody(photos: [ExportedPhoto]) -> String {
        var parts: [String] = [""]
        let refs = photos.map { photo in
            photo.isVideo
                ? videoReference(markdownPath: photo.markdownPath)
                : imageReference(markdownPath: photo.markdownPath)
        }
        parts.append(contentsOf: refs)
        parts.append("")
        parts.append("")
        return parts.joined(separator: "\n")
    }

    /// Overwrites a specific file URL — used when re-editing an existing post.
    static func write(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
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
