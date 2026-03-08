// Constants.swift — Shared between main app and Share Extension

enum Constants {
    static let appGroupID = "group.com.blogger.app"
    static let urlScheme = "blogger"
    static let newPostURL = "blogger://new-post"

    enum AppGroup {
        static let pendingDirectory = "pending"
        static let pendingMetadataFilename = "pending.json"
    }

    enum UserDefaultsKeys {
        static let baseBlogPath = "baseBlogPath"
        static let contentPath = "contentPath"
        static let staticImagesPath = "staticImagesPath"
        static let imageURLPrefix = "imageURLPrefix"
        static let contentSubpath = "contentSubpath"
        static let staticImagesSubpath = "staticImagesSubpath"
        static let knownCategories = "knownCategories"
        static let appTheme = "appTheme"
    }
}
