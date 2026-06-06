import XCTest
@testable import Photolog

final class ClusteringEngineTests: XCTestCase {
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
