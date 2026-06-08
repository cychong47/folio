import CoreLocation
import Foundation

struct GeocodeResult {
    let locationName: String
    let timeZone: TimeZone?
}

struct GeocodePlacemarkComponents {
    let name: String?
    let areasOfInterest: [String]?
    let subThoroughfare: String?
    let thoroughfare: String?
    let subLocality: String?
    let locality: String?
    let administrativeArea: String?

    init(
        name: String? = nil,
        areasOfInterest: [String]? = nil,
        subThoroughfare: String? = nil,
        thoroughfare: String? = nil,
        subLocality: String? = nil,
        locality: String? = nil,
        administrativeArea: String? = nil
    ) {
        self.name = name
        self.areasOfInterest = areasOfInterest
        self.subThoroughfare = subThoroughfare
        self.thoroughfare = thoroughfare
        self.subLocality = subLocality
        self.locality = locality
        self.administrativeArea = administrativeArea
    }

    init(placemark: CLPlacemark) {
        self.init(
            name: placemark.name,
            areasOfInterest: placemark.areasOfInterest,
            subThoroughfare: placemark.subThoroughfare,
            thoroughfare: placemark.thoroughfare,
            subLocality: placemark.subLocality,
            locality: placemark.locality,
            administrativeArea: placemark.administrativeArea
        )
    }
}

actor CurationGeocodeCache {
    private var cache: [String: GeocodeResult] = [:]

    func result(
        for coordinate: CLLocationCoordinate2D,
        lookup: () async -> GeocodeResult
    ) async -> GeocodeResult {
        let key = Self.key(for: coordinate)
        if let cached = cache[key] {
            return cached
        }

        let result = await lookup()
        cache[key] = result
        return result
    }

    private static func key(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.2f,%.2f", coordinate.latitude, coordinate.longitude)
    }
}

enum CurationGeocoder {
    private static let cache = CurationGeocodeCache()

    static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> GeocodeResult {
        await cache.result(for: coordinate) {
            await fetchReverseGeocode(coordinate: coordinate)
        }
    }

    private static func fetchReverseGeocode(coordinate: CLLocationCoordinate2D) async -> GeocodeResult {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first {
            let fallback = coordinateFallbackName(coordinate)
            let name = locationName(
                from: GeocodePlacemarkComponents(placemark: placemark),
                fallback: fallback
            )
            return GeocodeResult(locationName: name, timeZone: placemark.timeZone)
        }

        return GeocodeResult(locationName: coordinateFallbackName(coordinate), timeZone: nil)
    }

    static func locationName(from placemark: GeocodePlacemarkComponents, fallback: String) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap(cleaned)
            .joined(separator: " ")
        let areaOfInterest = placemark.areasOfInterest?.compactMap(cleaned).first
        let placeName = street.isEmpty ? cleaned(placemark.name) : nil

        let candidates = [
            areaOfInterest,
            street.isEmpty ? nil : street,
            placeName,
            cleaned(placemark.subLocality),
            cleaned(placemark.locality),
            cleaned(placemark.administrativeArea)
        ]

        var seen = Set<String>()
        let parts = candidates.compactMap { value -> String? in
            guard let value else { return nil }
            let key = value.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return value
        }

        return parts.isEmpty ? fallback : parts.joined(separator: ", ")
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func coordinateFallbackName(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.3f°, %.3f°", coordinate.latitude, coordinate.longitude)
    }
}
