import XCTest
@testable import Photolog

final class ClusteringEngineTests: XCTestCase {
    func testClustersDoNotOverlapByDisplayedCaptureLocalTime() {
        let eastTimeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let westTimeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let onePM = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 13, minute: 0, timeZone: eastTimeZone),
            captureTimeZone: eastTimeZone,
            coordinate: nil,
            pixelSize: .zero
        )
        let oneThirtySevenPM = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 13, minute: 37, timeZone: eastTimeZone),
            captureTimeZone: eastTimeZone,
            coordinate: nil,
            pixelSize: .zero
        )
        let oneThirteenPM = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 13, minute: 13, timeZone: westTimeZone),
            captureTimeZone: westTimeZone,
            coordinate: nil,
            pixelSize: .zero
        )

        let clusters = ClusteringEngine.cluster(
            assets: [onePM, oneThirtySevenPM, oneThirteenPM],
            temporalThreshold: 20 * 60,
            spatialThreshold: 500,
            maxEventDuration: 4 * 3600
        )

        XCTAssertEqual(clusters.count, 2)
        XCTAssertLessThanOrEqual(
            clusters[0].displayEndSortDate.timeIntervalSince1970,
            clusters[1].displaySortDate.timeIntervalSince1970
        )
    }

    func testGeneratedEventNamesFollowFinalDisplaySortOrder() {
        let eastTimeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let westTimeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let lateLocalAsset = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 18, minute: 1, timeZone: eastTimeZone),
            captureTimeZone: eastTimeZone,
            coordinate: nil,
            pixelSize: .zero
        )
        let earlierLocalAsset = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 11, minute: 52, timeZone: westTimeZone),
            captureTimeZone: westTimeZone,
            coordinate: nil,
            pixelSize: .zero
        )

        let clusters = ClusteringEngine.cluster(
            assets: [lateLocalAsset, earlierLocalAsset],
            temporalThreshold: 60,
            spatialThreshold: 500
        )

        XCTAssertEqual(clusters.map(\.name), ["Event 1", "Event 2"])
        XCTAssertLessThan(clusters[0].displaySortDate, clusters[1].displaySortDate)
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int = 0,
        second: Int = 0,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }
}
