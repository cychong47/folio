import Foundation

enum CategoryScanner {
    /// Walks all .md files under contentPath and returns a sorted unique list of categories.
    static func scan(contentPath: String) -> [String] {
        let base = URL(fileURLWithPath: contentPath)
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var seen = Set<String>()   // lowercase keys for case-insensitive dedup
        var categories: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "md" {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for cat in parseFrontmatterCategories(from: content) {
                if seen.insert(cat.lowercased()).inserted {
                    categories.append(cat)
                }
            }
        }
        return categories.sorted()
    }

    /// Parses the `categories:` value from a markdown frontmatter block.
    /// Handles both single-line `categories: ["Cat1", "Cat2"]` and
    /// multi-line YAML list format:
    ///   categories:
    ///     - Cat1
    ///     - Cat2
    static func parseFrontmatterCategories(from content: String) -> [String] {
        let quoteChars = CharacterSet(charactersIn: "\"'")

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
}
