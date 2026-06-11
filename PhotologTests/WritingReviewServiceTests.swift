import XCTest
@testable import Photolog

final class WritingReviewServiceTests: XCTestCase {
    func testFindsCommonKoreanWritingCorrections() {
        let issues = WritingReviewService.review(markdown: "이렇게 하면 안되요. 몇일 뒤에 할께요.")

        XCTAssertEqual(issues.map(\.replacement), ["안 돼요", "며칠", "할게요"])
        XCTAssertEqual(issues.map(\.kind), [.koreanWriting, .koreanWriting, .koreanWriting])
    }

    func testFindsMissingMarkdownImageAltText() {
        let issues = WritingReviewService.review(markdown: "![](/images/photo.jpg)\n![caption](/images/ok.jpg)")

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.kind, .missingAltText)
        XCTAssertEqual(issues.first?.excerpt, "![](/images/photo.jpg)")
    }

    func testFindsRepeatedAdjacentWords() {
        let issues = WritingReviewService.review(markdown: "오늘은 정말 정말 좋은 날입니다.")

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.kind, .repetition)
        XCTAssertEqual(issues.first?.replacement, "정말")
    }

    func testApplyReplacesOnlyIssueRange() {
        let body = "이렇게 하면 안되요."
        let issue = WritingReviewService.review(markdown: body).first!

        let updated = WritingReviewService.apply(issue: issue, to: body)

        XCTAssertEqual(updated, "이렇게 하면 안 돼요.")
    }
}
