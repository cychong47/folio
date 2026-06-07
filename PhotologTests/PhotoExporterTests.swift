import XCTest
@testable import Photolog

final class PhotoExporterTests: XCTestCase {
    func testReadEXIFDateUsesSharedParserForFractionalOffsetTimestamp() throws {
        let expected = date(
            year: 2026,
            month: 3,
            day: 14,
            hour: 12,
            minute: 1,
            second: 40,
            timeZone: TimeZone(secondsFromGMT: -7 * 3600)!
        ).addingTimeInterval(0.217)

        XCTAssertEqual(
            PhotoExporter.readEXIFDate(from: [
                kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2026:03:14 12:01:40.217",
                kCGImagePropertyExifOffsetTimeOriginal as String: "-07:00"
            ]
            ])?.timeIntervalSince1970 ?? 0,
            expected.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
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
