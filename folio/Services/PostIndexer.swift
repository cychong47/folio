import Foundation

enum PostIndexer {
    /// Scans all .md files under contentPath, parses frontmatter, and returns posts sorted by date descending.
    static func scan(contentPath: String) -> [PostSummary] {
        let base = URL(fileURLWithPath: contentPath)
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [PostSummary] = []
        for case let url as URL in enumerator where url.pathExtension == "md" {
            guard let content = try? String(contentsOf: url, encoding: .utf8),
                  let summary = parse(fileURL: url, content: content) else { continue }
            results.append(summary)
        }
        return results.sorted { $0.date > $1.date }
    }

    private static func parse(fileURL: URL, content: String) -> PostSummary? {
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }

        var fmEnd = -1
        for (i, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                fmEnd = i + 1
                break
            }
        }
        guard fmEnd > 0 else { return nil }

        let frontmatter = lines[1..<fmEnd].joined(separator: "\n")
        let body = fmEnd + 1 < lines.count ? lines[(fmEnd + 1)...].joined(separator: "\n") : ""

        let title = parseScalar(key: "title", from: frontmatter)
            ?? fileURL.deletingPathExtension().lastPathComponent
        let date = parseDate(parseScalar(key: "date", from: frontmatter))
        let isDraft = parseScalar(key: "draft", from: frontmatter) == "true"
        let categories = CategoryScanner.parseFrontmatterCategories(from: content)
        let tags = CategoryScanner.parseFrontmatterTags(from: content)
        let series = CategoryScanner.parseFrontmatterSeries(from: content) ?? ""
        let slug = deriveSlug(from: fileURL)

        return PostSummary(
            fileURL: fileURL,
            title: title,
            date: date,
            slug: slug,
            categories: categories,
            tags: tags,
            series: series,
            isDraft: isDraft,
            bodyText: body
        )
    }

    /// Strips the YYYY-MM-DD- date prefix from the filename to get the slug.
    private static func deriveSlug(from url: URL) -> String {
        let baseName = url.deletingPathExtension().lastPathComponent
        guard baseName.count > 11 else { return baseName }
        let datePart = String(baseName.prefix(10))
        let rest = baseName.dropFirst(10)
        let isDate = datePart.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
        if isDate, rest.first == "-" {
            return String(rest.dropFirst())
        }
        return baseName
    }

    /// Extracts a plain scalar value for `key:` from a frontmatter string.
    private static func parseScalar(key: String, from frontmatter: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: key)
        let pattern = "(?m)^\(escaped):\\s*(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: frontmatter,
                range: NSRange(frontmatter.startIndex..., in: frontmatter)
              ),
              let range = Range(match.range(at: 1), in: frontmatter) else { return nil }
        let value = String(frontmatter[range]).trimmingCharacters(in: .whitespaces)
        let quoteChars = CharacterSet(charactersIn: "\"'")
        return value.trimmingCharacters(in: quoteChars)
    }

    private static func parseDate(_ str: String?) -> Date {
        guard let str else { return Date() }
        let isoFormatter = DateFormatter()
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let d = isoFormatter.date(from: str) { return d }
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        return dateOnly.date(from: str) ?? Date()
    }
}
