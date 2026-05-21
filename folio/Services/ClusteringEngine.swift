import Foundation
import CoreLocation

enum ClusteringEngine {
    static let defaultTemporalThreshold: TimeInterval = 5400  // 90 min
    static let defaultSpatialThreshold: Double = 500          // metres
    static let burstThreshold: TimeInterval = 3               // seconds

    static func cluster(
        assets: [CurationAsset],
        temporalThreshold: TimeInterval = defaultTemporalThreshold,
        spatialThreshold: Double = defaultSpatialThreshold
    ) -> [EventCluster] {
        guard !assets.isEmpty else { return [] }
        let sorted = assets.sorted { $0.timestamp < $1.timestamp }
        var groups: [[CurationAsset]] = [[sorted[0]]]

        for i in 1 ..< sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            let dd: Double = {
                guard let a = prev.coordinate, let b = curr.coordinate else { return 0 }
                return haversine(a, b)
            }()
            if dt > temporalThreshold || (dd > spatialThreshold && dt > 60) {
                groups.append([curr])
            } else {
                groups[groups.count - 1].append(curr)
            }
        }

        return groups.enumerated().map { (idx, group) in
            let stacked = detectBursts(in: group)
            let dates = stacked.map(\.timestamp)
            return EventCluster(
                name: "Event \(idx + 1)",
                assets: stacked,
                startDate: dates.min() ?? Date(),
                endDate: dates.max() ?? Date()
            )
        }
    }

    private static func detectBursts(in assets: [CurationAsset]) -> [CurationAsset] {
        var result = assets
        var i = 0
        while i < result.count {
            var j = i + 1
            var burstGroup: [Int] = [i]
            while j < result.count {
                let dt = result[j].timestamp.timeIntervalSince(result[i].timestamp)
                if dt <= burstThreshold { burstGroup.append(j); j += 1 }
                else { break }
            }
            if burstGroup.count > 1 {
                let stackID = UUID()
                // primary = largest file (proxy for sharpest)
                let primaryIdx = burstGroup.max(by: { a, b in
                    let sA = (try? FileManager.default.attributesOfItem(atPath: result[a].url.path)[.size] as? Int) ?? 0
                    let sB = (try? FileManager.default.attributesOfItem(atPath: result[b].url.path)[.size] as? Int) ?? 0
                    return sA < sB
                }) ?? burstGroup[0]
                for idx in burstGroup {
                    result[idx].stackID = stackID
                    result[idx].isStackPrimary = (idx == primaryIdx)
                }
            }
            i = j
        }
        return result
    }

    private static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
        let Δφ = (b.latitude - a.latitude) * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let x = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
        return R * 2 * atan2(sqrt(x), sqrt(1 - x))
    }
}
