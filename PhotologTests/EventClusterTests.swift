import XCTest
@testable import Photolog

final class EventClusterTests: XCTestCase {
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
