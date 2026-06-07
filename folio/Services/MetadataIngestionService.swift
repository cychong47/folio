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

    static func makeAsset(from url: URL) -> CurationAsset {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return CurationAsset(phAsset: nil, url: url, timestamp: fileDate(url), captureTimeZone: nil, coordinate: nil, pixelSize: .zero)
        }

        let exifTimestamp = exifTimestamp(from: props)
        let timestamp = exifTimestamp?.date ?? fileDate(url)
        let coordinate = gpsCoordinate(from: props)
        let cameraModel = cameraModel(from: props)
        let w = props[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
        let h = props[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0

        return CurationAsset(
            phAsset: nil,
            url: url,
            timestamp: timestamp,
            captureTimeZone: exifTimestamp?.timeZone,
            coordinate: coordinate,
            pixelSize: CGSize(width: w, height: h),
            cameraModel: cameraModel
        )
    }

    static func cameraModel(from data: Data) -> String? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        return cameraModel(from: props)
    }

    static func gpsCoordinate(from data: Data) -> CLLocationCoordinate2D? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        return gpsCoordinate(from: props)
    }

    static func cameraModel(from props: [String: Any]) -> String? {
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let make = cleanedCameraComponent(tiff?[kCGImagePropertyTIFFMake as String])
        let model = cleanedCameraComponent(tiff?[kCGImagePropertyTIFFModel as String])

        switch (make, model) {
        case let (make?, model?):
            if model.range(of: make, options: [.caseInsensitive, .anchored]) != nil {
                return model
            }
            return "\(make) \(model)"
        case let (make?, nil):
            return make
        case let (nil, model?):
            return model
        default:
            return nil
        }
    }

    static func exifTimestamp(from data: Data, assumedTimeZone: TimeZone? = nil) -> (date: Date, timeZone: TimeZone?)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return nil
        }
        return exifTimestamp(from: props, assumedTimeZone: assumedTimeZone)
    }

    static func exifTimestamp(
        from props: [String: Any],
        assumedTimeZone: TimeZone? = nil
    ) -> (date: Date, timeZone: TimeZone?)? {
        let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        let rawDate = (exif?[kCGImagePropertyExifDateTimeOriginal as String] as? String)
               ?? (tiff?[kCGImagePropertyTIFFDateTime as String] as? String)
        let raw = appendSubsecondIfNeeded(
            to: rawDate,
            subsecond: exif?[kCGImagePropertyExifSubsecTimeOriginal as String] as? String
        )
        guard let raw else { return nil }

        if let inlineOffset = inlineEXIFOffset(in: raw),
           let date = parseEXIFDate(raw, formats: [
               "yyyy:MM:dd HH:mm:ss.SSSXXXXX",
               "yyyy:MM:dd HH:mm:ssXXXXX"
           ]) {
            return (date, timeZone(fromEXIFOffset: inlineOffset))
        }

        if let offset = exif?[kCGImagePropertyExifOffsetTimeOriginal as String] as? String {
            if let date = parseEXIFDate(raw + offset, formats: [
                "yyyy:MM:dd HH:mm:ss.SSSXXXXX",
                "yyyy:MM:dd HH:mm:ssXXXXX"
            ]) {
                return (date, timeZone(fromEXIFOffset: offset))
            }
        }

        guard let date = parseEXIFDate(raw, formats: [
            "yyyy:MM:dd HH:mm:ss.SSS",
            "yyyy:MM:dd HH:mm:ss"
        ], timeZone: assumedTimeZone) else { return nil }
        return (date, assumedTimeZone)
    }

    private static func cleanedCameraComponent(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func parseEXIFDate(
        _ raw: String,
        formats: [String],
        timeZone: TimeZone? = nil
    ) -> Date? {
        for format in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = format
            if let timeZone {
                f.timeZone = timeZone
            }
            if let date = f.date(from: raw) {
                return date
            }
        }
        return nil
    }

    private static func appendSubsecondIfNeeded(to raw: String?, subsecond: String?) -> String? {
        guard let raw,
              !raw.contains("."),
              let subsecond,
              !subsecond.isEmpty else { return raw }
        return raw + "." + subsecond
    }

    private static func inlineEXIFOffset(in raw: String) -> String? {
        guard raw.count >= 6 else { return nil }
        let offset = String(raw.suffix(6))
        return timeZone(fromEXIFOffset: offset) == nil ? nil : offset
    }

    private static func timeZone(fromEXIFOffset offset: String) -> TimeZone? {
        guard offset.count == 6,
              let sign = offset.first,
              sign == "+" || sign == "-",
              offset[offset.index(offset.startIndex, offsetBy: 3)] == ":",
              let hours = Int(offset.dropFirst().prefix(2)),
              let minutes = Int(offset.suffix(2)) else {
            return nil
        }
        let seconds = (hours * 3600 + minutes * 60) * (sign == "-" ? -1 : 1)
        return TimeZone(secondsFromGMT: seconds)
    }

    static func gpsCoordinate(from props: [String: Any]) -> CLLocationCoordinate2D? {
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
