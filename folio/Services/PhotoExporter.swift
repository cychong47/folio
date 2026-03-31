import Foundation
import ImageIO
import AppKit

enum PhotoExporter {
    static func exportedFilename(originalName: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)

        // Sanitise the original name
        let nameOnly = (originalName as NSString).deletingPathExtension
        let ext = (originalName as NSString).pathExtension
        let sanitised = nameOnly
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined()
        let normalised = ext.lowercased() == "jpeg" ? "jpg" : ext.lowercased()
        let filename = "\(dateStr)-\(sanitised)"
        return normalised.isEmpty ? filename : "\(filename).\(normalised)"
    }

    static func markdownImagePath(filename: String, settings: AppSettings) -> String {
        let prefix = settings.imageURLPrefix.hasSuffix("/") ? settings.imageURLPrefix : settings.imageURLPrefix + "/"
        return "\(prefix)\(filename)"
    }

    static func readEXIFDate(from data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return exifDate(from: source)
    }

    // Memory-efficient variant: reads only metadata, not the full image
    static func readEXIFDate(from url: URL) -> Date? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return exifDate(from: source)
    }

    /// Best available date for any image:
    ///  1. EXIF DateTimeOriginal (camera photos)
    ///  2. PHAsset creationDate via UUID in the exported filename (Photos.app drags, when authorized)
    ///  3. File creation date
    ///  4. Today as last resort
    static func readDate(from url: URL) -> Date {
        if let d = readEXIFDate(from: url) { return d }
        if let d = PhotoLibraryDate.creationDate(forExportedFile: url) { return d }
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.creationDate] as? Date) ?? Date()
    }

    private static func exifDate(from source: CGImageSource) -> Date? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    @discardableResult
    static func copyPendingToStatic(photos: [ExportedPhoto], settings: AppSettings) throws -> [URL] {
        let base = URL(fileURLWithPath: settings.staticImagesPath)
        let maxDim = settings.activeProfile?.maxImageDimension
        let strip = settings.activeProfile?.stripEXIF ?? true
        var written: [URL] = []
        for photo in photos {
            // Resolve subpath per-photo using its EXIF date
            let subpath = AppSettings.resolveSubpath(settings.staticImagesSubpath, for: photo.exifDate)
            let destDir = subpath.isEmpty ? base : base.appendingPathComponent(subpath, isDirectory: true)
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            let dest = destDir.appendingPathComponent(photo.filename)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            if let maxDim, let resized = resized(url: photo.localURL, maxLongEdge: maxDim) {
                let final = strip ? stripped(data: resized, url: photo.localURL) ?? resized : resized
                try final.write(to: dest)
            } else if strip, let stripped = stripped(url: photo.localURL) {
                try stripped.write(to: dest)
            } else {
                try FileManager.default.copyItem(at: photo.localURL, to: dest)
            }
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: dest.path)
            written.append(dest)
        }
        return written
    }

    /// Re-encodes image data with GPS and sensitive EXIF fields removed.
    private static func stripped(data: Data, url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return strippedFromSource(source, url: url)
    }

    /// Re-encodes image at url with GPS and sensitive EXIF fields removed.
    private static func stripped(url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return strippedFromSource(source, url: url)
    }

    private static func strippedFromSource(_ source: CGImageSource, url: URL) -> Data? {
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let uti: CFString = (url.pathExtension.lowercased() == "png" ? "public.png" : "public.jpeg") as CFString
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti, 1, nil) else { return nil }
        // Pass nil properties to write the image with no metadata
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.92,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageMetadataShouldExcludeXMP: false
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    /// Returns JPEG/PNG data for the image resized so its long edge ≤ maxLongEdge, or nil if no resize is needed.
    private static func resized(url: URL, maxLongEdge: Int) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let w = cgImage.width, h = cgImage.height
        guard max(w, h) > maxLongEdge else { return nil }
        let scale = CGFloat(maxLongEdge) / CGFloat(max(w, h))
        let newW = Int((CGFloat(w) * scale).rounded())
        let newH = Int((CGFloat(h) * scale).rounded())
        guard let ctx = CGContext(
            data: nil, width: newW, height: newH,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        guard let outImage = ctx.makeImage() else { return nil }
        let uti: CFString = (url.pathExtension.lowercased() == "png" ? "public.png" : "public.jpeg") as CFString
        let data = NSMutableData()
        guard let imgDest = CGImageDestinationCreateWithData(data, uti, 1, nil) else { return nil }
        CGImageDestinationAddImage(imgDest, outImage, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(imgDest)
        return data as Data
    }
}
