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
        static let blogProfiles = "blogProfiles"
        static let selectedProfileID = "selectedProfileID"
        static let appTheme = "appTheme"
    }
}
