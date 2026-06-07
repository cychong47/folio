import CoreLocation
import XCTest
@testable import Photolog

final class CurationGeocoderTests: XCTestCase {
    func testGeocodeCacheHandlesConcurrentAccessForSameCoordinate() async {
        let cache = CurationGeocodeCache()
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        await withTaskGroup(of: GeocodeResult.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    await cache.result(for: coordinate) {
                        GeocodeResult(locationName: "San Francisco", timeZone: TimeZone(secondsFromGMT: -8 * 3600))
                    }
                }
            }

            for await result in group {
                XCTAssertEqual(result.locationName, "San Francisco")
            }
        }
    }
}
