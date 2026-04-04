import Foundation

enum TaxonomyKind: String, CaseIterable, Identifiable {
    case categories, tags, series
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct TaxonomyTerm: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let postCount: Int
}

enum TaxonomyManager {

    /// Walks all .md files under contentPath and returns terms with post counts per kind.
    static func scan(contentPath: String) -> [TaxonomyKind: [TaxonomyTerm]] {
        let base = URL(fileURLWithPath: contentPath)
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [:] }

        var catCounts:    [String: Int] = [:]
        var tagCounts:    [String: Int] = [:]
        var seriesCounts: [String: Int] = [:]

        for case let url as URL in enumerator where url.pathExtension == "md" {
            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for cat in CategoryScanner.parseFrontmatterCategories(from: content) {
                catCounts[cat, default: 0] += 1
            }
            for tag in CategoryScanner.parseFrontmatterTags(from: content) {
                tagCounts[tag, default: 0] += 1
            }
            if let s = CategoryScanner.parseFrontmatterSeries(from: content) {
                seriesCounts[s, default: 0] += 1
            }
        }

        func toTerms(_ counts: [String: Int]) -> [TaxonomyTerm] {
            counts.map { TaxonomyTerm(name: $0.key, postCount: $0.value) }
                  .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        return [
            .categories: toTerms(catCounts),
            .tags:        toTerms(tagCounts),
            .series:      toTerms(seriesCounts),
        ]
    }

    /// Renames `oldName` to `newName` for the given kind across all .md files.
    /// Returns the count of modified files.
    @discardableResult
    static func rename(
        from oldName: String,
        to newName: String,
        kind: TaxonomyKind,
        in contentPath: String
    ) throws -> Int {
        let base = URL(fileURLWithPath: contentPath)
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var modifiedCount = 0
        for case let url as URL in enumerator where url.pathExtension == "md" {
            guard let original = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let rewritten = rewriteTerm(in: original, replacing: oldName, with: newName, kind: kind) {
                try rewritten.write(to: url, atomically: true, encoding: .utf8)
                modifiedCount += 1
            }
        }
        return modifiedCount
    }

    /// Merges `source` into `target` (replacing source with target) across all .md files.
    /// Returns the count of modified files.
    @discardableResult
    static func merge(
        source: String,
        into target: String,
        kind: TaxonomyKind,
        in contentPath: String
    ) throws -> Int {
        try rename(from: source, to: target, kind: kind, in: contentPath)
    }

    // MARK: - Private

    /// Rewrites a single term within frontmatter, returning nil if nothing changed.
    private static func rewriteTerm(
        in content: String,
        replacing old: String,
        with new: String,
        kind: TaxonomyKind
    ) -> String? {
        guard let fmRange = frontmatterRange(in: content) else { return nil }
        let frontmatter = String(content[fmRange])
        let key = kind.rawValue

        var newFrontmatter: String? = nil

        // Try single-line flow: key: [A, B, ...]
        let singleLinePattern = "(?m)^(\(key):\\s*\\[)([^\\]]*)(\\])"
        if let regex = try? NSRegularExpression(pattern: singleLinePattern),
           let match = regex.firstMatch(in: frontmatter,
                                        range: NSRange(frontmatter.startIndex..., in: frontmatter)) {
            let fullRange   = Range(match.range, in: frontmatter)!
            let insideRange = Range(match.range(at: 2), in: frontmatter)!
            let inside = String(frontmatter[insideRange])
            let quoteChars = CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}")
            var items = inside.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                  .trimmingCharacters(in: quoteChars)
            }.filter { !$0.isEmpty }
            guard items.contains(where: { $0.caseInsensitiveCompare(old) == .orderedSame })
            else { return nil }
            items = items.map { $0.caseInsensitiveCompare(old) == .orderedSame ? new : $0 }
            // deduplicate preserving first occurrence
            var seen = Set<String>()
            items = items.filter { seen.insert($0.lowercased()).inserted }
            let prefix = String(frontmatter[fullRange].prefix(
                frontmatter[fullRange].distance(from: frontmatter[fullRange].startIndex,
                                                to: frontmatter[insideRange].startIndex)
            ))
            _ = prefix // suppress warning; rebuild from match groups
            let g1 = String(frontmatter[Range(match.range(at: 1), in: frontmatter)!])
            let g3 = String(frontmatter[Range(match.range(at: 3), in: frontmatter)!])
            let replacement = g1 + items.joined(separator: ", ") + g3
            newFrontmatter = frontmatter.replacingCharacters(in: fullRange, with: replacement)
        }

        // Try multi-line block: key:\n  - A\n  - B
        if newFrontmatter == nil {
            let multiLinePattern = "(?m)^(\(key):\\s*\\n)((?:[ \\t]*-[ \\t]+[^\\n]+\\n?)+)"
            if let regex = try? NSRegularExpression(pattern: multiLinePattern),
               let match = regex.firstMatch(in: frontmatter,
                                             range: NSRange(frontmatter.startIndex..., in: frontmatter)) {
                let blockRange  = Range(match.range(at: 2), in: frontmatter)!
                let block = String(frontmatter[blockRange])
                let quoteChars = CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}")
                let lines = block.components(separatedBy: "\n")
                var hasMatch = false
                var newLines: [String] = []
                var seenNames = Set<String>()
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("-") else {
                        if !line.isEmpty { newLines.append(line) }
                        continue
                    }
                    let name = String(trimmed.dropFirst())
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: quoteChars)
                    let effectiveName = name.caseInsensitiveCompare(old) == .orderedSame ? new : name
                    if effectiveName != name { hasMatch = true }
                    if seenNames.insert(effectiveName.lowercased()).inserted {
                        let indent = String(line.prefix(line.count - line.drop(while: { $0 == " " || $0 == "\t" }).count))
                        newLines.append("\(indent)- \(effectiveName)")
                    }
                }
                guard hasMatch else { return nil }
                let newBlock = newLines.joined(separator: "\n") + "\n"
                let header = String(frontmatter[Range(match.range(at: 1), in: frontmatter)!])
                let fullMatchRange = Range(match.range, in: frontmatter)!
                newFrontmatter = frontmatter.replacingCharacters(in: fullMatchRange, with: header + newBlock)
            }
        }

        // Try scalar for series: series: Name
        if newFrontmatter == nil && kind == .series {
            let scalarPattern = "(?m)^(series:\\s*)([^\\[\\n][^\\n]*)$"
            if let regex = try? NSRegularExpression(pattern: scalarPattern),
               let match = regex.firstMatch(in: frontmatter,
                                             range: NSRange(frontmatter.startIndex..., in: frontmatter)) {
                let valueRange = Range(match.range(at: 2), in: frontmatter)!
                let quoteChars = CharacterSet(charactersIn: "\"'\u{201C}\u{201D}\u{2018}\u{2019}")
                let current = String(frontmatter[valueRange])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: quoteChars)
                guard current.caseInsensitiveCompare(old) == .orderedSame else { return nil }
                let prefix = String(frontmatter[Range(match.range(at: 1), in: frontmatter)!])
                let fullMatchRange = Range(match.range, in: frontmatter)!
                newFrontmatter = frontmatter.replacingCharacters(in: fullMatchRange, with: prefix + new)
            }
        }

        guard let updated = newFrontmatter else { return nil }
        return content.replacingCharacters(in: fmRange, with: updated)
    }

    /// Returns the range of the frontmatter block (between the two `---` delimiters, inclusive).
    private static func frontmatterRange(in content: String) -> Range<String.Index>? {
        guard content.hasPrefix("---") else { return nil }
        let lines = content.components(separatedBy: "\n")
        guard lines.count > 1 else { return nil }
        var endLine: Int? = nil
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                endLine = i
                break
            }
        }
        guard let end = endLine else { return nil }
        let fmText = lines[0...end].joined(separator: "\n")
        return content.startIndex..<content.index(content.startIndex, offsetBy: fmText.count)
    }
}
