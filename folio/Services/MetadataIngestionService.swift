import Foundation
import ImageIO
import CoreLocation
import AppKit
import Photos

enum MetadataIngestionService {
    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "raw", "cr2", "nef", "arw", "dng"]

    /// Scans folder recursively; calls progress(completed, total) on main thread.
    static func scan(folder: URL, progress: @escaping (Int, Int) -> Void) async -> [CurationAsset] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            guard imageExtensions.contains(url.pathExtension.lowercased()) else { continue }
            urls.append(url)
        }

        let total = urls.count
        var assets: [CurationAsset] = []
        assets.reserveCapacity(total)

        for (i, url) in urls.enumerated() {
            let asset = makeAsset(from: url)
            assets.append(asset)
            let completed = i + 1
            if completed % 10 == 0 || completed == total {
                await MainActor.run { progress(completed, total) }
            }
        }

        return assets.sorted { $0.timestamp < $1.timestamp }
    }

    /// Fetches PHAssets within the given date range from the system Photos library.
    static func scan(startDate: Date, endDate: Date, progress: @escaping (Int, Int) -> Void) async -> [CurationAsset] {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            print("[Folio] PhotoKit scan skipped — authorization status: \(status.rawValue)")
            return []
        }

        // Expand endDate to end of day
        let dayEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as CVarArg, dayEnd as CVarArg
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        // Do not set includeAssetSourceTypes — default covers all user library photos

        // PHAsset.fetchAssets must run on the main thread
        let result = await MainActor.run { PHAsset.fetchAssets(with: .image, options: options) }
        print("[Folio] PhotoKit fetch: \(result.count) assets (\(startDate) → \(dayEnd))")
        let total = result.count
        var assets: [CurationAsset] = []
        assets.reserveCapacity(total)

        for i in 0 ..< total {
            let ph = result.object(at: i)
            let coord: CLLocationCoordinate2D? = ph.location.map {
                CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            }
            let asset = CurationAsset(
                phAsset: ph,
                url: nil,
                timestamp: ph.creationDate ?? Date(),
                coordinate: coord,
                pixelSize: CGSize(width: ph.pixelWidth, height: ph.pixelHeight)
            )
            assets.append(asset)
            let done = i + 1
            if done % 10 == 0 || done == total {
                await MainActor.run { progress(done, total) }
            }
        }
        return assets
    }

    static func makeAsset(from url: URL) -> CurationAsset {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return CurationAsset(phAsset: nil, url: url, timestamp: fileDate(url), coordinate: nil, pixelSize: .zero)
        }

        let timestamp = exifDate(from: props) ?? fileDate(url)
        let coordinate = gpsCoordinate(from: props)
        let w = props[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
        let h = props[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0

        return CurationAsset(phAsset: nil, url: url, timestamp: timestamp, coordinate: coordinate, pixelSize: CGSize(width: w, height: h))
    }

    private static func exifDate(from props: [String: Any]) -> Date? {
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let raw = (exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String)
               ?? (tiff?[kCGImagePropertyTIFFDateTime as String] as? String)
        guard let raw else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f.date(from: raw)
    }

    private static func gpsCoordinate(from props: [String: Any]) -> CLLocationCoordinate2D? {
        guard let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double else { return nil }
        let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        return CLLocationCoordinate2D(
            latitude: latRef == "S" ? -lat : lat,
            longitude: lonRef == "W" ? -lon : lon
        )
    }

    private static func fileDate(_ url: URL) -> Date {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.creationDate] as? Date) ?? Date()
    }
}
