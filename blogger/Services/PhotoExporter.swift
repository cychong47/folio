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
        let filename = "\(dateStr)-\(sanitised)"
        return ext.isEmpty ? filename : "\(filename).\(ext)"
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

    private static func exifDate(from source: CGImageSource) -> Date? {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exifDict = props[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    static func copyPendingToStatic(photos: [ExportedPhoto], settings: AppSettings) throws {
        let destDir = URL(fileURLWithPath: settings.staticImagesPath)
        try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        for photo in photos {
            let dest = destDir.appendingPathComponent(photo.filename)
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: photo.localURL, to: dest)
        }
    }
}
