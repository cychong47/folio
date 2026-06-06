import Foundation

enum PhotoDateRangeFilter {
    struct Decision {
        var isIncluded: Bool
        var selectedStartDay: DateComponents
        var selectedEndDay: DateComponents
        var captureDay: DateComponents
        var selectionTimeZone: TimeZone
        var appliedTimeZone: TimeZone
    }

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
        decision(
            timestamp,
            captureTimeZone: captureTimeZone,
            displayTimeZone: displayTimeZone,
            startDate: startDate,
            endDate: endDate,
            selectionCalendar: selectionCalendar
        ).isIncluded
    }

    static func decision(
        _ timestamp: Date,
        captureTimeZone: TimeZone?,
        displayTimeZone: TimeZone? = nil,
        startDate: Date,
        endDate: Date,
        selectionCalendar: Calendar = .current
    ) -> Decision {
        let selectionStart = selectionCalendar.startOfDay(for: startDate)
        let selectionEnd = selectionCalendar.startOfDay(for: endDate)
        let appliedTimeZone = captureTimeZone ?? displayTimeZone ?? selectionCalendar.timeZone

        var captureCalendar = selectionCalendar
        captureCalendar.timeZone = appliedTimeZone

        let captureDay = captureCalendar.startOfDay(for: timestamp)
        let selectedStartComponents = selectionCalendar.dateComponents([.year, .month, .day], from: selectionStart)
        let selectedEndComponents = selectionCalendar.dateComponents([.year, .month, .day], from: selectionEnd)
        let captureComponents = captureCalendar.dateComponents([.year, .month, .day], from: captureDay)

        let selectedStartDay = comparableDay(from: selectedStartComponents)
        let selectedEndDay = comparableDay(from: selectedEndComponents)
        let captureDayValue = comparableDay(from: captureComponents)
        let isIncluded = selectedStartDay.flatMap { start in
            selectedEndDay.flatMap { end in
                captureDayValue.map { capture in capture >= start && capture <= end }
            }
        } ?? false

        return Decision(
            isIncluded: isIncluded,
            selectedStartDay: selectedStartComponents,
            selectedEndDay: selectedEndComponents,
            captureDay: captureComponents,
            selectionTimeZone: selectionCalendar.timeZone,
            appliedTimeZone: appliedTimeZone
        )
    }

    static func debugSummary(
        _ timestamp: Date,
        captureTimeZone: TimeZone?,
        displayTimeZone: TimeZone? = nil,
        startDate: Date,
        endDate: Date,
        selectionCalendar: Calendar = .current
    ) -> String {
        let decision = decision(
            timestamp,
            captureTimeZone: captureTimeZone,
            displayTimeZone: displayTimeZone,
            startDate: startDate,
            endDate: endDate,
            selectionCalendar: selectionCalendar
        )
        return [
            "selected=\(debugDay(decision.selectedStartDay))...\(debugDay(decision.selectedEndDay))",
            "captureDay=\(debugDay(decision.captureDay))",
            "selectionTZ=\(debugTimeZone(decision.selectionTimeZone))",
            "appliedTZ=\(debugTimeZone(decision.appliedTimeZone))"
        ].joined(separator: " | ")
    }

    private static func comparableDay(from components: DateComponents) -> Int? {
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return nil }
        return year * 10_000 + month * 100 + day
    }

    private static func debugDay(_ components: DateComponents) -> String {
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return "nil" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func debugTimeZone(_ timeZone: TimeZone) -> String {
        if timeZone.secondsFromGMT() == 0 { return "GMT" }
        let seconds = timeZone.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        return String(format: "GMT%@%02d:%02d", sign, absoluteSeconds / 3600, (absoluteSeconds % 3600) / 60)
    }
}
