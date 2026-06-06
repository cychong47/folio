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
        let interval = endDate.timeIntervalSince(startDate)
        if interval < 3600 { return "\(Int(interval / 60))m" }
        let h = Int(interval / 3600)
        let m = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    var displayTimeZone: TimeZone? {
        assets.sorted { $0.timestamp < $1.timestamp }.first?.captureTimeZone
    }

    func displayDateText(selectionTimeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = displayTimeZone ?? selectionTimeZone
        return formatter.string(from: startDate)
    }

    var representativeCoordinate: CLLocationCoordinate2D? {
        assets.compactMap(\.coordinate).first
    }
}
