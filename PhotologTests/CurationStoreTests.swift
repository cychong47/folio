import Photos
import XCTest
@testable import Photolog

final class CurationStoreTests: XCTestCase {
    func testPhotoLibraryMetadataRequestUsesOriginalHighQualityData() {
        let options = CurationStore.photoLibraryMetadataRequestOptions()

        XCTAssertEqual(options.version, PHImageRequestOptionsVersion.original)
        XCTAssertEqual(options.deliveryMode, PHImageRequestOptionsDeliveryMode.highQualityFormat)
        XCTAssertTrue(options.isNetworkAccessAllowed)
        XCTAssertFalse(options.isSynchronous)
    }
}
