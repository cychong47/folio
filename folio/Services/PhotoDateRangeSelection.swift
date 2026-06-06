import Foundation

enum PhotoDateRangeSelection {
    static let formatHint = "yyyy-MM-dd"

    static func string(from date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return "" }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(from string: String, calendar: Calendar = .current) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day

        guard let date = calendar.date(from: components) else { return nil }
        let resolved = calendar.dateComponents([.year, .month, .day], from: date)
        guard resolved.year == year,
              resolved.month == month,
              resolved.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    static func range(
        startText: String,
        endText: String,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        guard let start = date(from: startText, calendar: calendar),
              let end = date(from: endText, calendar: calendar),
              start <= end else { return nil }
        return (start, end)
    }
}
