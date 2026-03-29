import Foundation

struct BlogProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var blogRoot: String
    var contentPath: String
    var staticImagesPath: String
    var contentSubpath: String
    var staticImagesSubpath: String
    var knownCategories: [String]
    var knownSeries: [String]
    var githubToken: String
    var githubRepo: String
    var githubBranch: String

    init(
        id: UUID = UUID(),
        name: String,
        blogRoot: String = "",
        contentPath: String = "",
        staticImagesPath: String = "",
        contentSubpath: String = "YYYY/MM",
        staticImagesSubpath: String = "",
        knownCategories: [String] = [],
        knownSeries: [String] = [],
        githubToken: String = "",
        githubRepo: String = "",
        githubBranch: String = ""
    ) {
        self.id = id
        self.name = name
        self.blogRoot = blogRoot
        self.contentPath = contentPath
        self.staticImagesPath = staticImagesPath
        self.contentSubpath = contentSubpath
        self.staticImagesSubpath = staticImagesSubpath
        self.knownCategories = knownCategories
        self.knownSeries = knownSeries
        self.githubToken = githubToken
        self.githubRepo = githubRepo
        self.githubBranch = githubBranch
    }

    var isGitHubConfigured: Bool { !githubToken.isEmpty && !githubRepo.isEmpty }

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
