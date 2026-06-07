import CoreLocation
import Foundation

struct GeocodeResult {
    let locationName: String
    let timeZone: TimeZone?
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
            let parts = [placemark.locality, placemark.administrativeArea]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
            let name = parts.isEmpty
                ? coordinateFallbackName(coordinate)
                : parts.joined(separator: ", ")
            return GeocodeResult(locationName: name, timeZone: placemark.timeZone)
        }

        return GeocodeResult(locationName: coordinateFallbackName(coordinate), timeZone: nil)
    }

    private static func coordinateFallbackName(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.3f°, %.3f°", coordinate.latitude, coordinate.longitude)
    }
}
