import Foundation

class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var baseBlogPath: String {
        didSet { defaults.set(baseBlogPath, forKey: Constants.UserDefaultsKeys.baseBlogPath) }
    }

    @Published var contentPath: String {
        didSet { defaults.set(contentPath, forKey: Constants.UserDefaultsKeys.contentPath) }
    }

    @Published var staticImagesPath: String {
        didSet { defaults.set(staticImagesPath, forKey: Constants.UserDefaultsKeys.staticImagesPath) }
    }

    @Published var imageURLPrefix: String {
        didSet { defaults.set(imageURLPrefix, forKey: Constants.UserDefaultsKeys.imageURLPrefix) }
    }

    /// Subpath template under contentPath, e.g. "YYYY/MM" → 2026/03
    @Published var contentSubpath: String {
        didSet { defaults.set(contentSubpath, forKey: Constants.UserDefaultsKeys.contentSubpath) }
    }

    /// Subpath template under staticImagesPath, e.g. "YYYY/MM" → 2026/03
    @Published var staticImagesSubpath: String {
        didSet { defaults.set(staticImagesSubpath, forKey: Constants.UserDefaultsKeys.staticImagesSubpath) }
    }

    /// Categories collected from existing posts
    @Published var knownCategories: [String] {
        didSet { defaults.set(knownCategories, forKey: Constants.UserDefaultsKeys.knownCategories) }
    }

    /// App colour theme: "system" | "light" | "dark"
    @Published var appTheme: String {
        didSet { defaults.set(appTheme, forKey: Constants.UserDefaultsKeys.appTheme) }
    }

    init() {
        guard let defaults = UserDefaults(suiteName: Constants.appGroupID) else {
            fatalError("Cannot access App Group UserDefaults: \(Constants.appGroupID)")
        }
        self.defaults = defaults
        self.baseBlogPath = defaults.string(forKey: Constants.UserDefaultsKeys.baseBlogPath) ?? ""
        self.contentPath = defaults.string(forKey: Constants.UserDefaultsKeys.contentPath) ?? ""
        self.staticImagesPath = defaults.string(forKey: Constants.UserDefaultsKeys.staticImagesPath) ?? ""
        self.imageURLPrefix = defaults.string(forKey: Constants.UserDefaultsKeys.imageURLPrefix) ?? "/images"
        self.contentSubpath = defaults.string(forKey: Constants.UserDefaultsKeys.contentSubpath) ?? "YYYY/MM"
        self.staticImagesSubpath = defaults.string(forKey: Constants.UserDefaultsKeys.staticImagesSubpath) ?? ""
        // Normalize: strip stray quote characters and deduplicate, then persist back
        let raw = defaults.stringArray(forKey: Constants.UserDefaultsKeys.knownCategories) ?? []
        let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")
        var seen = Set<String>()
        let normalized = raw
            .map { $0.trimmingCharacters(in: quoteChars) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
        self.knownCategories = normalized
        defaults.set(normalized, forKey: Constants.UserDefaultsKeys.knownCategories)
        self.appTheme = defaults.string(forKey: Constants.UserDefaultsKeys.appTheme) ?? "system"
    }

    /// Resolves a subpath template against a date.
    static func resolveSubpath(_ template: String, for date: Date) -> String {
        let cal = Calendar.current
        let year  = String(format: "%04d", cal.component(.year,  from: date))
        let month = String(format: "%02d", cal.component(.month, from: date))
        let day   = String(format: "%02d", cal.component(.day,   from: date))
        return template
            .replacingOccurrences(of: "YYYY", with: year)
            .replacingOccurrences(of: "MM",   with: month)
            .replacingOccurrences(of: "DD",   with: day)
    }

    var isConfigured: Bool {
        !contentPath.isEmpty && !staticImagesPath.isEmpty
    }
}
