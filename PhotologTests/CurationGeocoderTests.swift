import CoreLocation
import XCTest
@testable import Photolog

final class CurationGeocoderTests: XCTestCase {
    func testLocationNamePrefersStreetLevelPlacemarkParts() {
        let name = CurationGeocoder.locationName(
            from: GeocodePlacemarkComponents(
                name: nil,
                areasOfInterest: nil,
                thoroughfare: "Market St",
                subLocality: "SoMa",
                locality: "San Francisco",
                administrativeArea: "CA"
            ),
            fallback: "37.775°, -122.419°"
        )

        XCTAssertEqual(name, "Market St, SoMa, San Francisco, CA")
    }

    func testLocationNameUsesAreaOfInterestBeforeStreetWhenAvailable() {
        let name = CurationGeocoder.locationName(
            from: GeocodePlacemarkComponents(
                name: nil,
                areasOfInterest: ["Ferry Building"],
                thoroughfare: "The Embarcadero",
                subLocality: nil,
                locality: "San Francisco",
                administrativeArea: "CA"
            ),
            fallback: "37.795°, -122.393°"
        )

        XCTAssertEqual(name, "Ferry Building, The Embarcadero, San Francisco, CA")
    }

    func testLocationNameDeduplicatesRepeatedPlacemarkParts() {
        let name = CurationGeocoder.locationName(
            from: GeocodePlacemarkComponents(
                name: "Golden Gate Park",
                areasOfInterest: ["Golden Gate Park"],
                thoroughfare: nil,
                subLocality: nil,
                locality: "San Francisco",
                administrativeArea: "CA"
            ),
            fallback: "37.769°, -122.486°"
        )

        XCTAssertEqual(name, "Golden Gate Park, San Francisco, CA")
    }

    func testLocationNameFallsBackWhenPlacemarkHasNoUsefulParts() {
        let name = CurationGeocoder.locationName(
            from: GeocodePlacemarkComponents(
                name: nil,
                areasOfInterest: nil,
                thoroughfare: nil,
                subLocality: nil,
                locality: nil,
                administrativeArea: nil
            ),
            fallback: "37.775°, -122.419°"
        )

        XCTAssertEqual(name, "37.775°, -122.419°")
    }

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
