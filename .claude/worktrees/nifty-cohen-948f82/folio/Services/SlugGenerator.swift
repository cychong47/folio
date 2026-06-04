import Foundation

enum SlugGenerator {
    static func slugify(_ input: String) -> String {
        input
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
            .components(separatedBy: "-")
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }
}
