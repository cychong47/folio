import Foundation

enum PhotoDateRangeFilter {
    static func photoKitQueryRange(
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let dayStart = calendar.startOfDay(for: startDate)
        let dayEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        return (
            calendar.date(byAdding: .day, value: -1, to: dayStart) ?? dayStart,
            calendar.date(byAdding: .day, value: 1, to: dayEnd) ?? dayEnd
        )
    }

    static func contains(
        _ timestamp: Date,
        captureTimeZone: TimeZone?,
        displayTimeZone: TimeZone? = nil,
        startDate: Date,
        endDate: Date,
        selectionCalendar: Calendar = .current
    ) -> Bool {
        let selectionStart = selectionCalendar.startOfDay(for: startDate)
        let selectionEnd = selectionCalendar.startOfDay(for: endDate)

        var captureCalendar = selectionCalendar
        if let timeZone = captureTimeZone ?? displayTimeZone {
            captureCalendar.timeZone = timeZone
        }

        let captureDay = captureCalendar.startOfDay(for: timestamp)
        let selectedStartComponents = selectionCalendar.dateComponents([.year, .month, .day], from: selectionStart)
        let selectedEndComponents = selectionCalendar.dateComponents([.year, .month, .day], from: selectionEnd)
        let captureComponents = captureCalendar.dateComponents([.year, .month, .day], from: captureDay)

        guard let selectedStartDay = comparableDay(from: selectedStartComponents),
              let selectedEndDay = comparableDay(from: selectedEndComponents),
              let captureDayValue = comparableDay(from: captureComponents) else {
            return false
        }

        return captureDayValue >= selectedStartDay && captureDayValue <= selectedEndDay
    }

    private static func comparableDay(from components: DateComponents) -> Int? {
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return nil }
        return year * 10_000 + month * 100 + day
    }
}
