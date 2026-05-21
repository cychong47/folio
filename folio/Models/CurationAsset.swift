import Foundation
import CoreLocation
import AppKit

struct CurationAsset: Identifiable, Hashable {
    var id: UUID = UUID()
    let url: URL
    var timestamp: Date
    var coordinate: CLLocationCoordinate2D?
    var pixelSize: CGSize
    var isSelected: Bool = false
    var stackID: UUID?        // non-nil = part of a burst/near-duplicate stack
    var isStackPrimary: Bool = false  // the frame shown when stack is collapsed

    var filename: String { url.lastPathComponent }

    static func == (lhs: CurationAsset, rhs: CurationAsset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
