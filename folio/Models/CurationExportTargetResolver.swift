import Foundation

enum CurationExportTargetResolver {
    enum Decision: Equatable {
        case use(BlogProfile)
        case choose([BlogProfile])
        case unavailable(String)
    }

    static func resolve(profiles: [BlogProfile], activeProfileID: UUID?) -> Decision {
        let configured = profiles.filter { !$0.staticImagesPath.isEmpty }
        guard !configured.isEmpty else {
            return .unavailable("No Static Images Path is configured. Open Settings and set the path for at least one blog profile.")
        }

        let distinctResizeSettings = Set(configured.map { ResizeSetting($0.maxImageDimension) })
        if configured.count > 1, distinctResizeSettings.count > 1 {
            return .choose(configured)
        }

        if let activeProfileID, let active = configured.first(where: { $0.id == activeProfileID }) {
            return .use(active)
        }
        return .use(configured[0])
    }

    private struct ResizeSetting: Hashable {
        let value: Int?

        init(_ value: Int?) {
            self.value = value
        }
    }
}
