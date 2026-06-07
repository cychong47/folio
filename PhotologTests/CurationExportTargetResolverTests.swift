import XCTest
@testable import Photolog

final class CurationExportTargetResolverTests: XCTestCase {
    func testUsesActiveProfileWhenConfiguredProfilesShareResizeSetting() {
        let activeID = UUID()
        let inactiveID = UUID()
        let active = profile(id: activeID, name: "Active", path: "/tmp/active", maxImageDimension: 1600)
        let inactive = profile(id: inactiveID, name: "Inactive", path: "/tmp/inactive", maxImageDimension: 1600)

        let decision = CurationExportTargetResolver.resolve(
            profiles: [inactive, active],
            activeProfileID: activeID
        )

        XCTAssertEqual(decision, .use(active))
    }

    func testPromptsWhenConfiguredProfilesHaveDifferentResizeSettings() {
        let first = profile(id: UUID(), name: "Small", path: "/tmp/small", maxImageDimension: 1024)
        let second = profile(id: UUID(), name: "Large", path: "/tmp/large", maxImageDimension: 2048)

        let decision = CurationExportTargetResolver.resolve(
            profiles: [first, second],
            activeProfileID: first.id
        )

        XCTAssertEqual(decision, .choose([first, second]))
    }

    func testIgnoresProfilesWithoutStaticImagePath() {
        let configured = profile(id: UUID(), name: "Configured", path: "/tmp/configured", maxImageDimension: nil)
        let incomplete = profile(id: UUID(), name: "Incomplete", path: "", maxImageDimension: 1024)

        let decision = CurationExportTargetResolver.resolve(
            profiles: [incomplete, configured],
            activeProfileID: incomplete.id
        )

        XCTAssertEqual(decision, .use(configured))
    }

    private func profile(
        id: UUID,
        name: String,
        path: String,
        maxImageDimension: Int?
    ) -> BlogProfile {
        BlogProfile(
            id: id,
            name: name,
            blogRoot: "/tmp/blog",
            contentPath: "/tmp/blog/content/posts",
            staticImagesPath: path,
            maxImageDimension: maxImageDimension
        )
    }
}
