import XCTest
@testable import Photolog

final class PhotoDateRangeFilterTests: XCTestCase {
    func testVisibleCaptureDateExcludesPreviousCaptureDayInsideSystemDay() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let captureTimeZone = TimeZone(secondsFromGMT: -8 * 3600)!
        let selectedDay = date(year: 2026, month: 3, day: 15, hour: 12, timeZone: systemTimeZone)
        let captureInstant = date(year: 2026, month: 3, day: 14, hour: 23, minute: 30, timeZone: captureTimeZone)

        XCTAssertFalse(PhotoDateRangeFilter.contains(
            captureInstant,
            captureTimeZone: captureTimeZone,
            startDate: selectedDay,
            endDate: selectedDay,
            selectionCalendar: calendar(timeZone: systemTimeZone)
        ))
    }

    func testVisibleCaptureDateIncludesSelectedCaptureDayOutsideSystemDay() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let captureTimeZone = TimeZone(secondsFromGMT: -10 * 3600)!
        let selectedDay = date(year: 2026, month: 3, day: 15, hour: 12, timeZone: systemTimeZone)
        let captureInstant = date(year: 2026, month: 3, day: 15, hour: 23, minute: 30, timeZone: captureTimeZone)

        XCTAssertTrue(PhotoDateRangeFilter.contains(
            captureInstant,
            captureTimeZone: captureTimeZone,
            startDate: selectedDay,
            endDate: selectedDay,
            selectionCalendar: calendar(timeZone: systemTimeZone)
        ))
    }

    func testDisplayTimeZoneExcludesNextDisplayedDayWhenEXIFTimeZoneIsMissing() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let displayTimeZone = TimeZone(secondsFromGMT: 14 * 3600)!
        let selectedDay = date(year: 2026, month: 3, day: 15, hour: 12, timeZone: systemTimeZone)
        let captureInstant = date(year: 2026, month: 3, day: 16, hour: 0, minute: 30, timeZone: displayTimeZone)

        XCTAssertFalse(PhotoDateRangeFilter.contains(
            captureInstant,
            captureTimeZone: nil,
            displayTimeZone: displayTimeZone,
            startDate: selectedDay,
            endDate: selectedDay,
            selectionCalendar: calendar(timeZone: systemTimeZone)
        ))
    }

    func testPhotoKitQueryRangeWidensByOneDayOnBothSides() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let selectedDay = date(year: 2026, month: 3, day: 15, hour: 12, timeZone: systemTimeZone)
        let range = PhotoDateRangeFilter.photoKitQueryRange(
            startDate: selectedDay,
            endDate: selectedDay,
            calendar: calendar(timeZone: systemTimeZone)
        )

        XCTAssertEqual(range.start, date(year: 2026, month: 3, day: 14, hour: 0, timeZone: systemTimeZone))
        XCTAssertEqual(range.end, date(year: 2026, month: 3, day: 16, hour: 23, minute: 59, second: 59, timeZone: systemTimeZone))
    }

    func testNoGPSPhotoLibraryCreationDateExcludesPreviousSelectedDay() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let selectedDay = date(year: 2026, month: 3, day: 15, hour: 12, timeZone: systemTimeZone)
        let photoLibraryCreationDate = isoDate("2026-03-13T18:47:02.691Z")

        XCTAssertFalse(PhotoDateRangeFilter.contains(
            photoLibraryCreationDate,
            captureTimeZone: nil,
            startDate: selectedDay,
            endDate: selectedDay,
            selectionCalendar: calendar(timeZone: systemTimeZone)
        ))
    }

    func testDebugSummaryShowsSelectedRangeAndCaptureDayForNoGPSCreationFallback() {
        let systemTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let selectedDay = date(year: 2026, month: 3, day: 15, hour: 12, timeZone: systemTimeZone)
        let photoLibraryCreationDate = isoDate("2026-03-13T18:47:02.691Z")

        let summary = PhotoDateRangeFilter.debugSummary(
            photoLibraryCreationDate,
            captureTimeZone: nil,
            startDate: selectedDay,
            endDate: selectedDay,
            selectionCalendar: calendar(timeZone: systemTimeZone)
        )

        XCTAssertEqual(
            summary,
            "selected=2026-03-15...2026-03-15 | captureDay=2026-03-14 | selectionTZ=GMT+09:00 | appliedTZ=GMT+09:00"
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
        calendar(timeZone: timeZone).date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    private func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private func isoDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }
}
