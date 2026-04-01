import Foundation

struct FrontmatterField: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var key: String
    var value: String
}

struct BlogProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var blogRoot: String
    var contentPath: String
    var staticImagesPath: String
    var contentSubpath: String
    var staticImagesSubpath: String
    var knownCategories: [String]
    var knownTags: [String] = []
    var knownSeries: [String]
    var autoScanEnabled: Bool
    var githubToken: String
    var githubRepo: String
    var githubBranch: String
    var customFrontmatterFields: [FrontmatterField]
    var maxImageDimension: Int?   // nil = no limit; otherwise max long-edge in pixels
    var stripEXIF: Bool           // remove GPS, device, and owner metadata on export

    init(
        id: UUID = UUID(),
        name: String,
        blogRoot: String = "",
        contentPath: String = "",
        staticImagesPath: String = "",
        contentSubpath: String = "YYYY/MM",
        staticImagesSubpath: String = "",
        knownCategories: [String] = [],
        knownTags: [String] = [],
        knownSeries: [String] = [],
        autoScanEnabled: Bool = false,
        githubToken: String = "",
        githubRepo: String = "",
        githubBranch: String = "",
        customFrontmatterFields: [FrontmatterField] = [],
        maxImageDimension: Int? = nil,
        stripEXIF: Bool = true
    ) {
        self.id = id
        self.name = name
        self.blogRoot = blogRoot
        self.contentPath = contentPath
        self.staticImagesPath = staticImagesPath
        self.contentSubpath = contentSubpath
        self.staticImagesSubpath = staticImagesSubpath
        self.knownCategories = knownCategories
        self.knownTags = knownTags
        self.knownSeries = knownSeries
        self.autoScanEnabled = autoScanEnabled
        self.githubToken = githubToken
        self.githubRepo = githubRepo
        self.githubBranch = githubBranch
        self.customFrontmatterFields = customFrontmatterFields
        self.maxImageDimension = maxImageDimension
        self.stripEXIF = stripEXIF
    }

    var isGitHubConfigured: Bool { !githubToken.isEmpty && !githubRepo.isEmpty }

    /// Parses `githubRepo` — accepts `owner/repo`, `https://github.com/owner/repo`,
    /// `https://codeberg.org/owner/repo`, etc.
    /// Returns `(apiBase, ownerRepo)` where apiBase already ends without a trailing slash.
    var resolvedRepoAPI: (apiBase: String, ownerRepo: String)? {
        let raw = githubRepo.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return nil }

        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            guard let url = URL(string: raw) else { return nil }
            let host = url.host ?? ""
            // path is "/owner/repo" or "/owner/repo.git"
            var path = url.path
                .replacingOccurrences(of: ".git", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let parts = path.split(separator: "/")
            guard parts.count >= 2 else { return nil }
            let ownerRepo = parts.prefix(2).joined(separator: "/")
            let apiBase: String
            if host == "github.com" {
                apiBase = "https://api.github.com/repos/\(ownerRepo)"
            } else {
                // Gitea-compatible hosts (Codeberg, Forgejo, self-hosted Gitea)
                apiBase = "https://\(host)/api/v1/repos/\(ownerRepo)"
            }
            return (apiBase, ownerRepo)
        } else {
            // Plain "owner/repo" — assume GitHub
            let ownerRepo = raw.replacingOccurrences(of: ".git", with: "")
            return ("https://api.github.com/repos/\(ownerRepo)", ownerRepo)
        }
    }

    /// URL-space path prefix for images, auto-derived from blogRoot and staticImagesPath.
    /// e.g. blogRoot=/…/blog staticImagesPath=/…/blog/static/images → /images
    var imageURLPrefix: String {
        guard !blogRoot.isEmpty, !staticImagesPath.isEmpty else { return "/images" }
        let staticDir = blogRoot + "/static"
        if staticImagesPath.hasPrefix(staticDir) {
            let suffix = String(staticImagesPath.dropFirst(staticDir.count))
            return suffix.isEmpty ? "/" : suffix
        }
        return "/images"
    }

    var isConfigured: Bool {
        !contentPath.isEmpty && !staticImagesPath.isEmpty
    }
}
