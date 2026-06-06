import Photos
import XCTest
@testable import Photolog

final class CurationStoreTests: XCTestCase {
    func testPhotoLibraryMetadataResourceRequestAllowsNetworkAccess() {
        let options = CurationStore.photoLibraryMetadataResourceRequestOptions()

        XCTAssertTrue(options.isNetworkAccessAllowed)
    }
}
