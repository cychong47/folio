import Foundation

class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    // MARK: - Scan state (published so views can observe)

    struct ScanInfo {
        let duration: TimeInterval
        let categoryCount: Int
        let tagCount: Int
        let seriesCount: Int
        let date: Date

        var displayText: String {
            let t = duration < 1 ? "\(Int(duration * 1000))ms" : String(format: "%.2fs", duration)
            return "\(t) · \(categoryCount) cat\(categoryCount == 1 ? "" : "s"), \(tagCount) tag\(tagCount == 1 ? "" : "s"), \(seriesCount) series"
        }
    }

    @Published var isScanning = false
    @Published var lastScanInfo: ScanInfo? = nil

    private var scanGeneration = 0
    private var autoScanTimer: Timer?
    private var lastAppliedAutoScanEnabled: Bool? = nil  // nil = not yet applied

    @Published var profiles: [BlogProfile] {
        didSet {
            saveProfiles()
            applyAutoScan()
        }
    }

    @Published var selectedProfileID: UUID? {
        didSet {
            defaults.set(selectedProfileID?.uuidString,
                         forKey: Constants.UserDefaultsKeys.selectedProfileID)
            lastAppliedAutoScanEnabled = nil  // force re-evaluate for new profile
            applyAutoScan()
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
    var knownTags: [String] {
        get { activeProfile?.knownTags ?? [] }
        set { updateActiveProfile { $0.knownTags = newValue } }
    }
    var knownSeries: [String] {
        get { activeProfile?.knownSeries ?? [] }
        set { updateActiveProfile { $0.knownSeries = newValue } }
    }
    var githubToken: String {
        get { activeProfile?.githubToken ?? "" }
        set { updateActiveProfile { $0.githubToken = newValue } }
    }
    var githubRepo: String {
        get { activeProfile?.githubRepo ?? "" }
        set { updateActiveProfile { $0.githubRepo = newValue } }
    }
    var githubBranch: String {
        get { activeProfile?.githubBranch ?? "" }
        set { updateActiveProfile { $0.githubBranch = newValue } }
    }
    var autoScanEnabled: Bool {
        get { activeProfile?.autoScanEnabled ?? false }
        set { updateActiveProfile { $0.autoScanEnabled = newValue } }
    }
    var isConfigured: Bool { activeProfile?.isConfigured ?? false }
    var isGitHubConfigured: Bool { activeProfile?.isGitHubConfigured ?? false }

    // MARK: - Init

    init() {
        guard let defaults = UserDefaults(suiteName: Constants.appGroupID) else {
            fatalError("Cannot access App Group UserDefaults: \(Constants.appGroupID)")
        }
        self.defaults = defaults
        self.appTheme = defaults.string(forKey: Constants.UserDefaultsKeys.appTheme) ?? "system"

        // Load from new multi-blog format
        let rawData = defaults.data(forKey: Constants.UserDefaultsKeys.blogProfiles)
        NSLog("[Folio] suite=%@ blogProfiles=%@", Constants.appGroupID, rawData.map { "\($0.count) bytes" } ?? "nil")
        if let data = rawData {
            if let decoded = try? JSONDecoder().decode([BlogProfile].self, from: data) {
                NSLog("[Folio] decode OK — %d profile(s), first=%@", decoded.count, decoded.first?.name ?? "?")
            } else {
                NSLog("[Folio] decode FAILED — json=%@", String(data: data, encoding: .utf8) ?? "unreadable")
            }
        }
        if let data = defaults.data(forKey: Constants.UserDefaultsKeys.blogProfiles),
           let decoded = try? JSONDecoder().decode([BlogProfile].self, from: data) {
            // Normalize categories in every profile: strip stray quotes, case-insensitive dedup
            let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")
            self.profiles = decoded.map { profile in
                var p = profile
                var seen = Set<String>()
                p.knownCategories = p.knownCategories
                    .map { $0.trimmingCharacters(in: quoteChars) }
                    .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
                    .sorted()
                return p
            }
            if let idStr = defaults.string(forKey: Constants.UserDefaultsKeys.selectedProfileID),
               let id = UUID(uuidString: idStr) {
                self.selectedProfileID = id
            } else {
                self.selectedProfileID = decoded.first?.id
            }
            // Persist normalized profiles (didSet doesn't fire during init)
            if let normalized = try? JSONEncoder().encode(self.profiles) {
                defaults.set(normalized, forKey: Constants.UserDefaultsKeys.blogProfiles)
            }
        } else if let oldDefaults = UserDefaults(suiteName: "group.com.blogger.app"),
                  let data = oldDefaults.data(forKey: Constants.UserDefaultsKeys.blogProfiles),
                  let decoded = try? JSONDecoder().decode([BlogProfile].self, from: data),
                  !decoded.isEmpty {
            // Migrate from old Blogger app group (app was renamed from Blogger to Folio)
            self.profiles = decoded
            if let idStr = oldDefaults.string(forKey: Constants.UserDefaultsKeys.selectedProfileID),
               let id = UUID(uuidString: idStr) {
                self.selectedProfileID = id
            } else {
                self.selectedProfileID = decoded.first?.id
            }
            if let theme = oldDefaults.string(forKey: Constants.UserDefaultsKeys.appTheme) {
                self.appTheme = theme
                defaults.set(theme, forKey: Constants.UserDefaultsKeys.appTheme)
            }
            // Persist to new group so migration only runs once
            if let encoded = try? JSONEncoder().encode(self.profiles) {
                defaults.set(encoded, forKey: Constants.UserDefaultsKeys.blogProfiles)
                defaults.set(self.selectedProfileID?.uuidString, forKey: Constants.UserDefaultsKeys.selectedProfileID)
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
        // Start auto-scan timer if a profile already has it enabled
        applyAutoScan()
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

    // MARK: - Scanning

    /// Single entry point for both manual and automatic scans.
    /// Each call increments `scanGeneration`; a completion whose captured generation
    /// no longer matches is silently discarded, so a manual scan always wins over
    /// an in-flight auto-scan and vice-versa.
    func triggerScan() {
        guard !contentPath.isEmpty else { return }
        scanGeneration += 1
        let gen = scanGeneration
        isScanning = true
        let path = contentPath
        DispatchQueue.global(qos: .userInitiated).async {
            let start = Date()
            let result = CategoryScanner.scan(contentPath: path)
            let duration = Date().timeIntervalSince(start)
            DispatchQueue.main.async {
                guard gen == self.scanGeneration else { return }
                self.knownCategories = CategoryScanner.merge(self.knownCategories, result.categories)
                self.knownTags       = CategoryScanner.merge(self.knownTags,       result.tags)
                self.knownSeries     = CategoryScanner.merge(self.knownSeries,     result.series)
                self.lastScanInfo    = ScanInfo(duration: duration,
                                               categoryCount: result.categories.count,
                                               tagCount: result.tags.count,
                                               seriesCount: result.series.count,
                                               date: Date())
                self.isScanning = false
            }
        }
    }

    /// Starts or stops the 30-minute auto-scan timer based on the active profile's setting.
    /// No-ops when the enabled state hasn't changed, so frequent `profiles.didSet` calls
    /// from typing in other fields don't reset the countdown.
    private func applyAutoScan() {
        let enabled = autoScanEnabled
        guard enabled != lastAppliedAutoScanEnabled else { return }
        lastAppliedAutoScanEnabled = enabled
        autoScanTimer?.invalidate()
        autoScanTimer = nil
        guard enabled, !contentPath.isEmpty else { return }
        autoScanTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            self?.triggerScan()
        }
    }
}
