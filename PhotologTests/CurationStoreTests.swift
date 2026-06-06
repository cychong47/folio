import Photos
import XCTest
@testable import Photolog

final class CurationStoreTests: XCTestCase {
    func testPhotoLibraryMetadataResourceRequestAllowsNetworkAccess() {
        let options = CurationStore.photoLibraryMetadataResourceRequestOptions()

        XCTAssertTrue(options.isNetworkAccessAllowed)
    }

    func testPhotoLibraryTimestampUsesCreationDateWhenEXIFHasNoTimeZoneEvidence() {
        let exifDate = Date(timeIntervalSince1970: 1_765_000_000)
        let creationDate = Date(timeIntervalSince1970: 1_766_000_000)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: nil),
            locationTimeZone: nil,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, creationDate)
        XCTAssertNil(resolved.timeZone)
        XCTAssertEqual(resolved.source, "creation:ambiguous-exif")
    }

    func testPhotoLibraryTimestampKeepsEXIFWhenOffsetIsPresent() {
        let captureTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let exifDate = Date(timeIntervalSince1970: 1_765_000_000)
        let creationDate = Date(timeIntervalSince1970: 1_766_000_000)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: captureTimeZone),
            locationTimeZone: nil,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, exifDate)
        XCTAssertEqual(resolved.timeZone, captureTimeZone)
        XCTAssertEqual(resolved.source, "exif")
    }

    func testPhotoLibraryTimestampUsesCreationDateWhenGPSAssumedEXIFDivergesFromPhotosDate() {
        let gpsTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let exifDate = Date(timeIntervalSince1970: 1_765_000_000)
        let creationDate = exifDate.addingTimeInterval(8 * 3600)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: gpsTimeZone),
            locationTimeZone: gpsTimeZone,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, creationDate)
        XCTAssertNil(resolved.timeZone)
        XCTAssertEqual(resolved.source, "creation:diverged-exif")
    }
}
