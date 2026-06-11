import Foundation

enum WritingIssueKind: String, Equatable {
    case koreanWriting = "Korean Writing"
    case missingAltText = "Missing Alt Text"
    case repetition = "Repeated Word"
    case longSentence = "Long Sentence"
}

struct WritingIssue: Identifiable, Equatable {
    let id: String
    let kind: WritingIssueKind
    let message: String
    let excerpt: String
    let range: NSRange
    let replacement: String?
}

enum WritingReviewService {
    private struct Correction {
        let phrase: String
        let replacement: String
        let message: String
    }

    private static let koreanCorrections: [Correction] = [
        Correction(phrase: "안되요", replacement: "안 돼요", message: "'안 돼요' is the standard spelling."),
        Correction(phrase: "안돼요", replacement: "안 돼요", message: "'안 돼요' is clearer with spacing."),
        Correction(phrase: "몇일", replacement: "며칠", message: "'며칠' is the standard spelling."),
        Correction(phrase: "할께요", replacement: "할게요", message: "'할게요' is the standard spelling."),
        Correction(phrase: "될께요", replacement: "될게요", message: "'될게요' is the standard spelling."),
        Correction(phrase: "갈께요", replacement: "갈게요", message: "'갈게요' is the standard spelling."),
        Correction(phrase: "있슴", replacement: "있음", message: "'있음' is the standard spelling.")
    ]

    private static let missingAltRegex = try! NSRegularExpression(pattern: #"!\[\s*\]\([^)]+\)"#)
    private static let repeatedWordRegex = try! NSRegularExpression(pattern: #"(?<!\S)(\S+)\s+\1(?!\S)"#)
    private static let sentenceRegex = try! NSRegularExpression(pattern: #"[^.!?\n。！？]+[.!?。！？]?"#)

    static func review(markdown: String) -> [WritingIssue] {
        var issues: [WritingIssue] = []
        issues.append(contentsOf: koreanWritingIssues(in: markdown))
        issues.append(contentsOf: missingAltTextIssues(in: markdown))
        issues.append(contentsOf: repeatedWordIssues(in: markdown))
        issues.append(contentsOf: longSentenceIssues(in: markdown))
        return issues.sorted { $0.range.location < $1.range.location }
    }

    static func apply(issue: WritingIssue, to markdown: String) -> String {
        guard let replacement = issue.replacement,
              let range = Range(issue.range, in: markdown) else {
            return markdown
        }

        var updated = markdown
        updated.replaceSubrange(range, with: replacement)
        return updated
    }

    private static func koreanWritingIssues(in markdown: String) -> [WritingIssue] {
        var issues: [WritingIssue] = []
        for correction in koreanCorrections {
            var searchRange = markdown.startIndex..<markdown.endIndex
            while let range = markdown.range(of: correction.phrase, options: [], range: searchRange) {
                let nsRange = NSRange(range, in: markdown)
                issues.append(WritingIssue(
                    id: issueID(kind: .koreanWriting, range: nsRange, replacement: correction.replacement),
                    kind: .koreanWriting,
                    message: correction.message,
                    excerpt: String(markdown[range]),
                    range: nsRange,
                    replacement: correction.replacement
                ))
                searchRange = range.upperBound..<markdown.endIndex
            }
        }
        return issues
    }

    private static func missingAltTextIssues(in markdown: String) -> [WritingIssue] {
        let nsRange = NSRange(markdown.startIndex..., in: markdown)
        return missingAltRegex.matches(in: markdown, range: nsRange).map { match in
            let excerpt = String(markdown[Range(match.range, in: markdown)!])
            return WritingIssue(
                id: issueID(kind: .missingAltText, range: match.range, replacement: nil),
                kind: .missingAltText,
                message: "Add short alt text inside the square brackets.",
                excerpt: excerpt,
                range: match.range,
                replacement: nil
            )
        }
    }

    private static func repeatedWordIssues(in markdown: String) -> [WritingIssue] {
        let nsRange = NSRange(markdown.startIndex..., in: markdown)
        return repeatedWordRegex.matches(in: markdown, range: nsRange).compactMap { match in
            guard let matchRange = Range(match.range, in: markdown),
                  let wordRange = Range(match.range(at: 1), in: markdown) else {
                return nil
            }
            let word = String(markdown[wordRange])
            return WritingIssue(
                id: issueID(kind: .repetition, range: match.range, replacement: word),
                kind: .repetition,
                message: "This word appears twice in a row.",
                excerpt: String(markdown[matchRange]),
                range: match.range,
                replacement: word
            )
        }
    }

    private static func longSentenceIssues(in markdown: String) -> [WritingIssue] {
        let nsRange = NSRange(markdown.startIndex..., in: markdown)
        return sentenceRegex.matches(in: markdown, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: markdown) else { return nil }
            let sentence = String(markdown[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard sentence.count > 140, !sentence.hasPrefix("!") else { return nil }
            return WritingIssue(
                id: issueID(kind: .longSentence, range: match.range, replacement: nil),
                kind: .longSentence,
                message: "Consider splitting this sentence for readability.",
                excerpt: sentence,
                range: match.range,
                replacement: nil
            )
        }
    }

    private static func issueID(kind: WritingIssueKind, range: NSRange, replacement: String?) -> String {
        "\(kind.rawValue)-\(range.location)-\(range.length)-\(replacement ?? "none")"
    }
}
