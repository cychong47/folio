import XCTest
@testable import Photolog

final class EventClusterTests: XCTestCase {
    func testSortDateUsesDisplayedCaptureLocalTime() {
        let earlyDisplayZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let lateDisplayZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let morning = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 4, minute: 1, timeZone: earlyDisplayZone),
            captureTimeZone: earlyDisplayZone,
            coordinate: nil,
            pixelSize: .zero
        )
        let evening = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: date(year: 2026, month: 3, day: 15, hour: 18, minute: 1, timeZone: lateDisplayZone),
            captureTimeZone: lateDisplayZone,
            coordinate: nil,
            pixelSize: .zero
        )
        let clusters = [
            EventCluster(name: "Evening", assets: [evening], startDate: evening.timestamp, endDate: evening.timestamp),
            EventCluster(name: "Morning", assets: [morning], startDate: morning.timestamp, endDate: morning.timestamp)
        ].sorted { $0.displaySortDate < $1.displaySortDate }

        XCTAssertEqual(clusters.map(\.name), ["Morning", "Evening"])
    }

    func testDisplayTimestampUsesFirstAssetCaptureTimeZone() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let captureTimeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let timestamp = date(year: 2026, month: 3, day: 15, hour: 23, minute: 30, timeZone: captureTimeZone)
        let asset = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: timestamp,
            captureTimeZone: captureTimeZone,
            coordinate: nil,
            pixelSize: .zero
        )
        let cluster = EventCluster(
            name: "Event 1",
            assets: [asset],
            startDate: timestamp,
            endDate: timestamp
        )

        XCTAssertEqual(
            cluster.displayDateText(selectionTimeZone: systemTimeZone, locale: Locale(identifier: "en_US_POSIX")),
            "Mar 15, 2026 at 11:30\u{202F}PM"
        )
    }

    func testDisplayTimestampUsesSelectionTimeZoneForPhotosCreationDateFallbackWithoutCaptureZone() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let timestamp = date(year: 2026, month: 3, day: 15, hour: 7, minute: 9, timeZone: systemTimeZone)
        let asset = CurationAsset(
            phAsset: nil,
            url: nil,
            timestamp: timestamp,
            captureTimeZone: nil,
            coordinate: nil,
            pixelSize: .zero,
            usesPhotoLibraryCreationDate: true
        )
        let cluster = EventCluster(
            name: "Event 1",
            assets: [asset],
            startDate: timestamp,
            endDate: timestamp
        )

        XCTAssertEqual(
            cluster.displayDateText(selectionTimeZone: systemTimeZone, locale: Locale(identifier: "en_US_POSIX")),
            "Mar 15, 2026 at 7:09\u{202F}AM"
        )
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
