import Foundation
import ImageIO
import CoreLocation
import AppKit

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
            await MainActor.run { progress(completed, total) }
        }

        return assets.sorted { $0.timestamp < $1.timestamp }
    }

    static func makeAsset(from url: URL) -> CurationAsset {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return CurationAsset(url: url, timestamp: fileDate(url), coordinate: nil, pixelSize: .zero)
        }

        let timestamp = exifDate(from: props) ?? fileDate(url)
        let coordinate = gpsCoordinate(from: props)
        let w = props[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
        let h = props[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0

        return CurationAsset(url: url, timestamp: timestamp, coordinate: coordinate, pixelSize: CGSize(width: w, height: h))
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
