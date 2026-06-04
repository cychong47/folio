import Foundation

enum SharedContainerService {
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupID)
    }

    static var pendingDirectoryURL: URL? {
        containerURL?.appendingPathComponent(Constants.AppGroup.pendingDirectory, isDirectory: true)
    }

    static var pendingMetadataURL: URL? {
        containerURL?.appendingPathComponent(Constants.AppGroup.pendingMetadataFilename)
    }

    static func loadPendingMetadata() throws -> PendingPostMetadata? {
        guard let url = pendingMetadataURL, FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PendingPostMetadata.self, from: data)
    }

    static func loadExportedPhotos() throws -> [ExportedPhoto] {
        guard let metadata = try loadPendingMetadata(),
              let pendingDir = pendingDirectoryURL else {
            return []
        }
        return metadata.photos.map { photo in
            ExportedPhoto(
                filename: photo.filename,
                markdownPath: photo.markdownPath,
                localURL: pendingDir.appendingPathComponent(photo.filename),
                exifDate: photo.exifDate
            )
        }
    }

    static func clearPending() throws {
        if let metaURL = pendingMetadataURL, FileManager.default.fileExists(atPath: metaURL.path) {
            try FileManager.default.removeItem(at: metaURL)
        }
        if let pendingDir = pendingDirectoryURL, FileManager.default.fileExists(atPath: pendingDir.path) {
            try FileManager.default.removeItem(at: pendingDir)
        }
    }
}
