import Foundation
import CoreLocation
import AppKit
import Photos

struct CurationAsset: Identifiable, Hashable {
    var id: UUID = UUID()
    var phAsset: PHAsset?     // set when source is PhotoKit
    var url: URL?             // set when source is file system
    var timestamp: Date
    var captureTimeZone: TimeZone?
    var coordinate: CLLocationCoordinate2D?
    var pixelSize: CGSize
    var isSelected: Bool = false
    var isScreenshot: Bool = false
    var isFavorite: Bool = false
    var stackID: UUID?        // non-nil = part of a burst/near-duplicate stack
    var isStackPrimary: Bool = false  // the frame shown when stack is collapsed
    var curationDiagnostic: String? = nil
    var usesPhotoLibraryCreationDate: Bool = false
    var cameraModel: String? = nil

    var preferredDisplayTimeZone: TimeZone? {
        captureTimeZone
    }

    var displaySortDate: Date {
        Self.displaySortDate(for: timestamp, timeZone: preferredDisplayTimeZone ?? .current)
    }

    var filename: String {
        if let url { return url.lastPathComponent }
        if let phAsset {
            return PHAssetResource.assetResources(for: phAsset).first?.originalFilename
                ?? phAsset.localIdentifier
        }
        return "photo"
    }

    static func displaySortDate(for timestamp: Date, timeZone: TimeZone) -> Date {
        var displayCalendar = Calendar(identifier: .gregorian)
        displayCalendar.timeZone = timeZone
        var sortCalendar = Calendar(identifier: .gregorian)
        sortCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt

        let components = displayCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .nanosecond],
            from: timestamp
        )
        return sortCalendar.date(from: components) ?? timestamp
    }

    static func == (lhs: CurationAsset, rhs: CurationAsset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
