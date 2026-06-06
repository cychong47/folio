import ImageIO
import XCTest
@testable import Photolog

final class MetadataIngestionServiceTests: XCTestCase {
    func testEXIFTimestampWithoutOffsetUsesAssumedCaptureTimeZone() {
        let captureTimeZone = TimeZone(secondsFromGMT: 3600)!
        let timestamp = MetadataIngestionService.exifTimestamp(
            from: [
                kCGImagePropertyExifDictionary as String: [
                    kCGImagePropertyExifDateTimeOriginal as String: "2026:03:15 11:01:00"
                ]
            ],
            assumedTimeZone: captureTimeZone
        )

        XCTAssertEqual(timestamp?.date, date(year: 2026, month: 3, day: 15, hour: 11, minute: 1, timeZone: captureTimeZone))
        XCTAssertEqual(timestamp?.timeZone, captureTimeZone)
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
