import Foundation
import Photos

/// Resolves a PHAsset creation date from the exported filename Photos.app gives
/// when delivering a file promise. The filename typically contains the asset's UUID,
/// which is the prefix of the PHAsset localIdentifier.
enum PhotoLibraryDate {

    private static let uuidRegex = try! NSRegularExpression(
        pattern: "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}",
        options: .caseInsensitive
    )

    /// Returns the PHAsset creation date for the given exported file URL, or nil if
    /// authorization is not granted or the UUID cannot be matched.
    static func creationDate(forExportedFile url: URL) -> Date? {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return nil }

        // Extract a UUID-like string from the filename (without extension)
        let stem = url.deletingPathExtension().lastPathComponent
        guard let match = uuidRegex.firstMatch(in: stem, range: NSRange(stem.startIndex..., in: stem)),
              let range = Range(match.range, in: stem) else { return nil }
        let uuidString = String(stem[range])

        // PHAsset.localIdentifier = "<UUID>/L0/001" (or /L0/000 for some assets)
        for suffix in ["/L0/001", "/L0/000"] {
            let results = PHAsset.fetchAssets(withLocalIdentifiers: [uuidString + suffix], options: nil)
            if let asset = results.firstObject {
                return asset.creationDate
            }
        }
        return nil
    }

    /// Requests photo library authorization. Call once from the UI (e.g. Settings).
    static func requestAuthorization() async {
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    static var isAuthorized: Bool {
        let s = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return s == .authorized || s == .limited
    }
}
