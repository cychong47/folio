import XCTest
@testable import Photolog

final class PhotoExporterTests: XCTestCase {
    func testCopyPendingToStaticKeepsPhotoAlreadyAtDestination() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let staticImages = root.appendingPathComponent("static/images", isDirectory: true)
        let imageDir = staticImages.appendingPathComponent("2026/03", isDirectory: true)
        try FileManager.default.createDirectory(at: imageDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let imageURL = imageDir.appendingPathComponent("IMG_3469.jpg")
        let originalData = Data("already exported".utf8)
        try originalData.write(to: imageURL)

        let defaultsSuite = "PhotoExporterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: defaultsSuite)!
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let settings = AppSettings(testDefaults: defaults)
        let profile = BlogProfile(
            name: "Test",
            blogRoot: root.path,
            contentPath: root.appendingPathComponent("content/posts").path,
            staticImagesPath: staticImages.path,
            staticImagesSubpath: "YYYY/MM",
            maxImageDimension: nil,
            stripEXIF: false
        )
        settings.profiles = [profile]
        settings.selectedProfileID = profile.id

        let written = try PhotoExporter.copyPendingToStatic(
            photos: [
                ExportedPhoto(
                    filename: "IMG_3469.jpg",
                    markdownPath: "/images/2026/03/IMG_3469.jpg",
                    localURL: imageURL,
                    exifDate: date(year: 2026, month: 3, day: 15)
                )
            ],
            settings: settings
        )

        XCTAssertEqual(written, [imageURL])
        XCTAssertEqual(try Data(contentsOf: imageURL), originalData)
    }

    func testReadEXIFDateUsesSharedParserForFractionalOffsetTimestamp() throws {
        let expected = date(
            year: 2026,
            month: 3,
            day: 14,
            hour: 12,
            minute: 1,
            second: 40,
            timeZone: TimeZone(secondsFromGMT: -7 * 3600)!
        ).addingTimeInterval(0.217)

        XCTAssertEqual(
            PhotoExporter.readEXIFDate(from: [
                kCGImagePropertyExifDictionary as String: [
                kCGImagePropertyExifDateTimeOriginal as String: "2026:03:14 12:01:40.217",
                kCGImagePropertyExifOffsetTimeOriginal as String: "-07:00"
            ]
            ])?.timeIntervalSince1970 ?? 0,
            expected.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int
    ) -> Date {
        date(
            year: year,
            month: month,
            day: day,
            hour: 0,
            minute: 0,
            second: 0,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }
}
