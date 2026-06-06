import XCTest
@testable import Photolog

final class PhotoDateRangeSelectionTests: XCTestCase {
    func testDateStringParsesAsSelectedCalendarDay() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let selected = PhotoDateRangeSelection.date(
            from: "2026-03-15",
            calendar: calendar(timeZone: systemTimeZone)
        )

        XCTAssertEqual(
            selected,
            date(year: 2026, month: 3, day: 15, timeZone: systemTimeZone)
        )
    }

    func testDateStringRejectsInvalidCalendarDay() {
        XCTAssertNil(PhotoDateRangeSelection.date(
            from: "2026-02-30",
            calendar: calendar(timeZone: TimeZone(secondsFromGMT: 9 * 3600)!)
        ))
    }

    func testRangeRejectsEndBeforeStart() {
        XCTAssertNil(PhotoDateRangeSelection.range(
            startText: "2026-03-15",
            endText: "2026-03-14",
            calendar: calendar(timeZone: TimeZone(secondsFromGMT: 9 * 3600)!)
        ))
    }

    private func date(year: Int, month: Int, day: Int, timeZone: TimeZone) -> Date {
        calendar(timeZone: timeZone).date(from: DateComponents(
            year: year,
            month: month,
            day: day
        ))!
    }

    private func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
