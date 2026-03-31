import Foundation

enum CategoryScanner {
    struct ScanResult {
        var categories: [String]
        var series: [String]
    }

    /// Walks all .md files under contentPath and returns sorted unique categories and series.
    static func scan(contentPath: String) -> ScanResult {
        let base = URL(fileURLWithPath: contentPath)
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return ScanResult(categories: [], series: []) }

        var seenCats = Set<String>()
        var seenSeries = Set<String>()
        var categories: [String] = []
        var series: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "md" {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for cat in parseFrontmatterCategories(from: content) {
                if seenCats.insert(cat.lowercased()).inserted { categories.append(cat) }
            }
            if let s = parseFrontmatterSeries(from: content) {
                if seenSeries.insert(s.lowercased()).inserted { series.append(s) }
            }
        }
        return ScanResult(categories: categories.sorted(), series: series.sorted())
    }

    /// Merges two sorted lists, deduplicating case-insensitively and stripping stray quotes.
    static func merge(_ existing: [String], _ new: [String]) -> [String] {
        let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")
        var seen = Set<String>()
        var result: [String] = []
        for item in existing + new {
            let cleaned = item.trimmingCharacters(in: quoteChars)
            guard !cleaned.isEmpty, seen.insert(cleaned.lowercased()).inserted else { continue }
            result.append(cleaned)
        }
        return result.sorted()
    }

    /// Parses the `categories:` value from a markdown frontmatter block.
    /// Handles both single-line `categories: ["Cat1", "Cat2"]` and
    /// multi-line YAML list format:
    ///   categories:
    ///     - Cat1
    ///     - Cat2
    static func parseFrontmatterCategories(from content: String) -> [String] {
        // Include curly/smart quotes so they are stripped the same way AppSettings.init does
        let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")

        // Single-line: categories: [Cat1, "Cat2", ...]
        if let range = content.range(
            of: #"(?m)^categories:\s*\[([^\]]*)\]"#,
            options: .regularExpression
        ) {
            let match = String(content[range])
            if let open = match.firstIndex(of: "["),
               let close = match.lastIndex(of: "]") {
                let inside = String(match[match.index(after: open)..<close])
                guard !inside.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
                return inside.components(separatedBy: ",").compactMap { item in
                    let trimmed = item
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: quoteChars)
                    return trimmed.isEmpty ? nil : trimmed
                }
            }
        }

        // Multi-line:
        // categories:
        //   - Cat1
        //   - Cat2
        if let range = content.range(
            of: #"(?m)^categories:\s*\n((?:[ \t]*-[ \t]+[^\n]+\n?)+)"#,
            options: .regularExpression
        ) {
            let block = String(content[range])
            return block.components(separatedBy: "\n").compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("-") else { return nil }
                let value = String(trimmed.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: quoteChars)
                return value.isEmpty ? nil : value
            }
        }

        return []
    }

    /// Parses the `series:` value from a markdown frontmatter block.
    /// Returns the first (and typically only) series name, or nil if absent.
    static func parseFrontmatterSeries(from content: String) -> String? {
        let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")

        // Single-line flow: series: [Name] or series: ["Name"]
        if let range = content.range(
            of: #"(?m)^series:\s*\[([^\]]*)\]"#,
            options: .regularExpression
        ) {
            let match = String(content[range])
            if let open = match.firstIndex(of: "["),
               let close = match.lastIndex(of: "]") {
                let inside = String(match[match.index(after: open)..<close])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: quoteChars)
                return inside.isEmpty ? nil : inside
            }
        }

        // Scalar: series: Name  or  series: "Name"
        if let range = content.range(
            of: #"(?m)^series:\s*([^\[\n][^\n]*)$"#,
            options: .regularExpression
        ) {
            let match = String(content[range])
            if let colon = match.firstIndex(of: ":") {
                let value = String(match[match.index(after: colon)...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: quoteChars)
                return value.isEmpty ? nil : value
            }
        }

        // Multi-line list: series:\n  - Name
        if let range = content.range(
            of: #"(?m)^series:\s*\n((?:[ \t]*-[ \t]+[^\n]+\n?)+)"#,
            options: .regularExpression
        ) {
            let block = String(content[range])
            for line in block.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("-") else { continue }
                let value = String(trimmed.dropFirst())
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: quoteChars)
                if !value.isEmpty { return value }
            }
        }

        return nil
    }
}
