import XCTest
@testable import Photolog

final class PostEditorRightPanelModeTests: XCTestCase {
    func testDefaultModeIsPreview() {
        XCTAssertEqual(PostEditorRightPanelMode.defaultMode, .preview)
    }

    func testModesArePreviewAndReviseInDisplayOrder() {
        XCTAssertEqual(PostEditorRightPanelMode.allCases, [.preview, .revise])
        XCTAssertEqual(PostEditorRightPanelMode.preview.title, "Preview")
        XCTAssertEqual(PostEditorRightPanelMode.revise.title, "Revise")
    }
}
