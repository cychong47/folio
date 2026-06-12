import XCTest
@testable import Photolog

final class WritingReviewServiceTests: XCTestCase {
    func testFindsCommonKoreanWritingCorrections() {
        let issues = WritingReviewService.review(markdown: "이렇게 하면 안되요. 몇일 뒤에 할께요.")

        XCTAssertEqual(issues.map(\.replacement), ["안 돼요", "며칠", "할게요"])
        XCTAssertEqual(issues.map(\.kind), [.koreanWriting, .koreanWriting, .koreanWriting])
    }

    func testFindsExpandedKoreanWritingCorrections() {
        let body = "왠만하면 오랫만에 어떻해라고 쓰지 마세요. 작성됬습니다."

        let issues = WritingReviewService.review(markdown: body)

        XCTAssertEqual(issues.map(\.replacement), ["웬만하면", "오랜만에", "어떡해", "작성됐습니다"])
        XCTAssertTrue(issues.allSatisfy { $0.kind == .koreanWriting })
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

    func testGroupsIssuesByReviewSection() {
        let issues = WritingReviewService.review(markdown: "몇일 정말 정말\n![](/images/photo.jpg)")

        let groups = WritingReviewService.groupedIssues(issues)

        XCTAssertEqual(groups.map(\.title), ["Korean spelling", "Repeated words", "Image alt text"])
        XCTAssertEqual(groups.map { $0.issues.count }, [1, 1, 1])
    }
}
