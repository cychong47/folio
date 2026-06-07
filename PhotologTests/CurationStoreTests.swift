import Photos
import XCTest
@testable import Photolog

final class CurationStoreTests: XCTestCase {
    @MainActor
    func testToggleFocusedAssetSelectionUsesVisibleAssetOrder() {
        let store = CurationStore()
        let firstID = UUID()
        let secondID = UUID()
        let firstDate = Date(timeIntervalSince1970: 200)
        let secondDate = Date(timeIntervalSince1970: 100)
        store.clusters = [
            EventCluster(
                name: "Event",
                assets: [
                    CurationAsset(id: firstID, timestamp: firstDate, pixelSize: .zero),
                    CurationAsset(id: secondID, timestamp: secondDate, pixelSize: .zero)
                ],
                startDate: secondDate,
                endDate: firstDate
            )
        ]
        store.focusedAssetIndex = 0

        store.toggleFocusedAssetSelection()

        XCTAssertFalse(store.clusters[0].assets[0].isSelected)
        XCTAssertTrue(store.clusters[0].assets[1].isSelected)
    }

    func testPhotoLibraryMetadataResourceRequestAllowsNetworkAccess() {
        let options = CurationStore.photoLibraryMetadataResourceRequestOptions()

        XCTAssertTrue(options.isNetworkAccessAllowed)
    }

    func testPhotoLibraryTimestampUsesEXIFWhenCameraTimeHasNoTimeZoneEvidence() {
        let exifDate = Date(timeIntervalSince1970: 1_765_000_000)
        let creationDate = Date(timeIntervalSince1970: 1_766_000_000)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: nil),
            locationTimeZone: nil,
            noLocationTimeZone: nil,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, exifDate)
        XCTAssertNil(resolved.timeZone)
        XCTAssertEqual(resolved.source, "exif:camera-local")
    }

    func testPhotoLibraryTimestampUsesCreationDateWhenEXIFIsMissing() {
        let creationDate = Date(timeIntervalSince1970: 1_766_000_000)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: nil,
            locationTimeZone: nil,
            noLocationTimeZone: nil,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, creationDate)
        XCTAssertNil(resolved.timeZone)
        XCTAssertEqual(resolved.source, "creation:no-exif")
    }

    func testNoGPSCameraLocalEXIFDoesNotUsePhotosCreationInstant() {
        let exifDate = isoDate("2026-03-13T02:47:02.691Z")
        let creationDate = isoDate("2026-03-13T18:47:02.691Z")
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: nil),
            locationTimeZone: nil,
            noLocationTimeZone: nil,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, exifDate)
        XCTAssertNil(resolved.timeZone)
        XCTAssertEqual(resolved.source, "exif:camera-local")
    }

    func testPhotoLibraryTimestampKeepsEXIFWhenOffsetIsPresent() {
        let captureTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let exifDate = Date(timeIntervalSince1970: 1_765_000_000)
        let creationDate = Date(timeIntervalSince1970: 1_766_000_000)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: captureTimeZone),
            locationTimeZone: nil,
            noLocationTimeZone: nil,
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
            noLocationTimeZone: nil,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, creationDate)
        XCTAssertNil(resolved.timeZone)
        XCTAssertEqual(resolved.source, "creation:diverged-exif")
    }

    func testPhotoLibraryTimestampUsesManualOffsetForNoLocationCameraTime() {
        let manualTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let exifDate = isoDate("2026-03-13T17:47:02.691Z")
        let creationDate = isoDate("2026-03-13T18:47:02.691Z")
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: manualTimeZone),
            locationTimeZone: nil,
            noLocationTimeZone: manualTimeZone,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, exifDate)
        XCTAssertEqual(resolved.timeZone, manualTimeZone)
        XCTAssertEqual(resolved.source, "exif:manual-offset")
    }

    func testManualOffsetDoesNotOverrideGPSAssumedTimestampResolution() {
        let gpsTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let manualTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let exifDate = Date(timeIntervalSince1970: 1_765_000_000)
        let creationDate = exifDate.addingTimeInterval(60)
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: exifDate, timeZone: gpsTimeZone),
            locationTimeZone: gpsTimeZone,
            noLocationTimeZone: manualTimeZone,
            creationDate: creationDate,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, exifDate)
        XCTAssertEqual(resolved.timeZone, gpsTimeZone)
        XCTAssertEqual(resolved.source, "exif")
    }

    func testGPSDisplayTimeZoneOverridesConflictingEXIFOffsetWhenInstantMatchesPhotosDate() {
        let gpsTimeZone = TimeZone(secondsFromGMT: -7 * 3600)!
        let exifTimeZone = TimeZone(secondsFromGMT: 9 * 3600)!
        let captureInstant = isoDate("2026-03-14T19:01:40.217Z")
        let resolved = CurationStore.resolvedPhotoLibraryTimestamp(
            exifTimestamp: (date: captureInstant, timeZone: exifTimeZone),
            locationTimeZone: gpsTimeZone,
            noLocationTimeZone: nil,
            creationDate: captureInstant,
            fallbackDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(resolved.date, captureInstant)
        XCTAssertEqual(resolved.timeZone, gpsTimeZone)
        XCTAssertEqual(resolved.source, "exif:gps-timezone")
    }

    private func isoDate(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)!
    }

}
