import Foundation

class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var profiles: [BlogProfile] {
        didSet { saveProfiles() }
    }

    @Published var selectedProfileID: UUID? {
        didSet {
            defaults.set(selectedProfileID?.uuidString,
                         forKey: Constants.UserDefaultsKeys.selectedProfileID)
        }
    }

    @Published var appTheme: String {
        didSet { defaults.set(appTheme, forKey: Constants.UserDefaultsKeys.appTheme) }
    }

    // MARK: - Active profile access

    var activeProfile: BlogProfile? {
        get {
            if let id = selectedProfileID { return profiles.first { $0.id == id } }
            return profiles.first
        }
        set {
            guard let updated = newValue,
                  let idx = profiles.firstIndex(where: { $0.id == updated.id }) else { return }
            profiles[idx] = updated
        }
    }

    func updateActiveProfile(_ block: (inout BlogProfile) -> Void) {
        guard let id = selectedProfileID ?? profiles.first?.id,
              let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        var updated = profiles[idx]
        block(&updated)
        profiles[idx] = updated  // explicit assignment ensures @Published fires
    }

    // MARK: - Forwarding computed properties (used by service layer)

    var contentPath: String { activeProfile?.contentPath ?? "" }
    var staticImagesPath: String { activeProfile?.staticImagesPath ?? "" }
    var imageURLPrefix: String { activeProfile?.imageURLPrefix ?? "/images" }
    var contentSubpath: String { activeProfile?.contentSubpath ?? "" }
    var staticImagesSubpath: String { activeProfile?.staticImagesSubpath ?? "" }
    var knownCategories: [String] {
        get { activeProfile?.knownCategories ?? [] }
        set { updateActiveProfile { $0.knownCategories = newValue } }
    }
    var isConfigured: Bool { activeProfile?.isConfigured ?? false }

    // MARK: - Init

    init() {
        guard let defaults = UserDefaults(suiteName: Constants.appGroupID) else {
            fatalError("Cannot access App Group UserDefaults: \(Constants.appGroupID)")
        }
        self.defaults = defaults
        self.appTheme = defaults.string(forKey: Constants.UserDefaultsKeys.appTheme) ?? "system"

        // Load from new multi-blog format
        if let data = defaults.data(forKey: Constants.UserDefaultsKeys.blogProfiles),
           let decoded = try? JSONDecoder().decode([BlogProfile].self, from: data) {
            self.profiles = decoded
            if let idStr = defaults.string(forKey: Constants.UserDefaultsKeys.selectedProfileID),
               let id = UUID(uuidString: idStr) {
                self.selectedProfileID = id
            } else {
                self.selectedProfileID = decoded.first?.id
            }
        } else {
            // Migrate from old single-blog keys
            let oldContent = defaults.string(forKey: "contentPath") ?? ""
            let oldImages  = defaults.string(forKey: "staticImagesPath") ?? ""
            if !oldContent.isEmpty || !oldImages.isEmpty {
                let oldBase    = defaults.string(forKey: "baseBlogPath") ?? ""
                let blogRoot   = oldBase.isEmpty ? Self.deriveBlogRoot(from: oldContent) : oldBase
                let rawCats    = defaults.stringArray(forKey: "knownCategories") ?? []
                let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")
                var seen       = Set<String>()
                let cats       = rawCats
                    .map { $0.trimmingCharacters(in: quoteChars) }
                    .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
                let profile = BlogProfile(
                    name: "sosa0sa",
                    blogRoot: blogRoot,
                    contentPath: oldContent,
                    staticImagesPath: oldImages,
                    contentSubpath: defaults.string(forKey: "contentSubpath") ?? "YYYY/MM",
                    staticImagesSubpath: defaults.string(forKey: "staticImagesSubpath") ?? "",
                    knownCategories: cats
                )
                self.profiles = [profile]
                self.selectedProfileID = profile.id
            } else {
                self.profiles = []
                self.selectedProfileID = nil
            }
        }
    }

    // MARK: - Persistence

    private func saveProfiles() {
        if let data = try? JSONEncoder().encode(profiles) {
            defaults.set(data, forKey: Constants.UserDefaultsKeys.blogProfiles)
        }
    }

    // MARK: - Helpers

    private static func deriveBlogRoot(from contentPath: String) -> String {
        for suffix in ["/content/posts", "/content/post", "/content"] {
            if contentPath.hasSuffix(suffix) {
                return String(contentPath.dropLast(suffix.count))
            }
        }
        return ""
    }

    static func resolveSubpath(_ template: String, for date: Date) -> String {
        let cal   = Calendar.current
        let year  = String(format: "%04d", cal.component(.year,  from: date))
        let month = String(format: "%02d", cal.component(.month, from: date))
        let day   = String(format: "%02d", cal.component(.day,   from: date))
        return template
            .replacingOccurrences(of: "YYYY", with: year)
            .replacingOccurrences(of: "MM",   with: month)
            .replacingOccurrences(of: "DD",   with: day)
    }
}
