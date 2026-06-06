import ImageIO
import XCTest
@testable import Photolog

final class MetadataIngestionServiceTests: XCTestCase {
    func testEXIFTimestampWithSeparatedSubsecondAndOffsetPreservesCaptureTimeZone() {
        let captureTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let timestamp = MetadataIngestionService.exifTimestamp(
            from: [
                kCGImagePropertyExifDictionary as String: [
                    kCGImagePropertyExifDateTimeOriginal as String: "2026:03:14 13:05:19",
                    kCGImagePropertyExifOffsetTimeOriginal as String: "-07:00",
                    kCGImagePropertyExifSubsecTimeOriginal as String: "528"
                ]
            ]
        )

        let expected = date(
            year: 2026,
            month: 3,
            day: 14,
            hour: 13,
            minute: 5,
            second: 19,
            timeZone: captureTimeZone
        ).addingTimeInterval(0.528)
        XCTAssertEqual(timestamp?.date.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(timestamp?.timeZone, captureTimeZone)
    }

    func testEXIFTimestampWithInlineFractionalSecondsAndOffsetPreservesCaptureTimeZone() {
        let captureTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let timestamp = MetadataIngestionService.exifTimestamp(
            from: [
                kCGImagePropertyExifDictionary as String: [
                    kCGImagePropertyExifDateTimeOriginal as String: "2026:03:14 12:01:40.217-07:00"
                ]
            ]
        )

        let expected = date(
            year: 2026,
            month: 3,
            day: 14,
            hour: 12,
            minute: 1,
            second: 40,
            timeZone: captureTimeZone
        ).addingTimeInterval(0.217)
        XCTAssertEqual(timestamp?.date.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(timestamp?.timeZone, captureTimeZone)
    }

    func testEXIFTimestampWithFractionalSecondsAndOffsetPreservesCaptureTimeZone() {
        let captureTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let timestamp = MetadataIngestionService.exifTimestamp(
            from: [
                kCGImagePropertyExifDictionary as String: [
                    kCGImagePropertyExifDateTimeOriginal as String: "2026:03:14 12:01:40.217",
                    kCGImagePropertyExifOffsetTimeOriginal as String: "-07:00"
                ]
            ]
        )

        let expected = date(
            year: 2026,
            month: 3,
            day: 14,
            hour: 12,
            minute: 1,
            second: 40,
            timeZone: captureTimeZone
        ).addingTimeInterval(0.217)
        XCTAssertEqual(timestamp?.date.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(timestamp?.timeZone, captureTimeZone)
    }

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
