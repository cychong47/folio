import Foundation
import CoreLocation

struct EventCluster: Identifiable {
    var id: UUID = UUID()
    var name: String
    var assets: [CurationAsset]
    var startDate: Date
    var endDate: Date

    var selectedCount: Int { assets.filter(\.isSelected).count }
    var totalCount: Int { assets.count }

    var durationFormatted: String {
        let interval = displayEndSortDate.timeIntervalSince(displaySortDate)
        if interval < 3600 { return "\(Int(interval / 60))m" }
        let h = Int(interval / 3600)
        let m = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    var displayTimeZone: TimeZone? {
        assets.sorted { $0.displaySortDate < $1.displaySortDate }.first?.preferredDisplayTimeZone
    }

    var displaySortDate: Date {
        assets.map(\.displaySortDate).min()
            ?? CurationAsset.displaySortDate(for: startDate, timeZone: displayTimeZone ?? .current)
    }

    var displayEndSortDate: Date {
        assets.map(\.displaySortDate).max()
            ?? CurationAsset.displaySortDate(for: endDate, timeZone: displayTimeZone ?? .current)
    }

    func displayDateText(selectionTimeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = displayTimeZone ?? selectionTimeZone
        return formatter.string(from: startDate)
    }

    func postCreationDate(selectionTimeZone: TimeZone = .current) -> Date {
        let displayTimeZone = displayTimeZone ?? selectionTimeZone
        var displayCalendar = Calendar(identifier: .gregorian)
        displayCalendar.timeZone = displayTimeZone
        var selectionCalendar = Calendar(identifier: .gregorian)
        selectionCalendar.timeZone = selectionTimeZone

        let components = displayCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: startDate
        )
        return selectionCalendar.date(from: components) ?? startDate
    }

    var representativeCoordinate: CLLocationCoordinate2D? {
        assets.compactMap(\.coordinate).first
    }
}
