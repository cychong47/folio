import Foundation
import CoreLocation

enum SplitMode: String, CaseIterable {
    case time = "Time"
    case location = "Location"
    case both = "Both"
}

enum ClusteringEngine {
    static let defaultTemporalThreshold: TimeInterval = 5400  // 90 min
    static let defaultSpatialThreshold: Double = 500          // metres
    static let defaultMaxEventDuration: TimeInterval = 14400  // 4 hours
    static let burstThreshold: TimeInterval = 3               // seconds

    private enum TimeLocationSplitRule {
        case timeOrLocation
        case timeAndLocation
    }

    static func cluster(
        assets: [CurationAsset],
        temporalThreshold: TimeInterval = defaultTemporalThreshold,
        spatialThreshold: Double = defaultSpatialThreshold,
        maxEventDuration: TimeInterval = defaultMaxEventDuration
    ) -> [EventCluster] {
        guard !assets.isEmpty else { return [] }

        let photos      = assets.filter { !$0.isScreenshot }
        let screenshots = assets.filter {  $0.isScreenshot }

        // Photos: cluster by time + location
        let photoGroups = clusterByTimeAndLocation(
            photos,
            temporalThreshold: temporalThreshold,
            spatialThreshold: spatialThreshold,
            maxEventDuration: maxEventDuration
        )

        // Screenshots: cluster by time only (no GPS on screenshots)
        let screenshotGroups = clusterByTimeOnly(
            screenshots,
            temporalThreshold: temporalThreshold,
            maxEventDuration: maxEventDuration
        )

        var clusters: [EventCluster] = []

        for (i, group) in photoGroups.enumerated() {
            let stacked = detectBursts(in: group)
            let dates = stacked.map(\.timestamp)
            clusters.append(EventCluster(
                name: "Event \(i + 1)",
                assets: stacked,
                startDate: dates.min() ?? Date(),
                endDate: dates.max() ?? Date()
            ))
        }

        for group in screenshotGroups {
            let stacked = detectBursts(in: group)
            let dates = stacked.map(\.timestamp)
            clusters.append(EventCluster(
                name: "Screenshots",
                assets: stacked,
                startDate: dates.min() ?? Date(),
                endDate: dates.max() ?? Date()
            ))
        }

        clusters.sort { $0.startDate < $1.startDate }
        return clusters
    }

    // MARK: - Public split API

    /// Returns a group index for each asset (same order as `assets`).
    static func computeGroupAssignments(
        assets: [CurationAsset],
        temporalThreshold: TimeInterval,
        spatialThreshold: Double,
        mode: SplitMode
    ) -> [Int] {
        let groups = splitIntoGroups(assets: assets, temporalThreshold: temporalThreshold,
                                     spatialThreshold: spatialThreshold, mode: mode)
        var groupForID: [UUID: Int] = [:]
        for (gi, group) in groups.enumerated() {
            for asset in group { groupForID[asset.id] = gi }
        }
        return assets.map { groupForID[$0.id] ?? 0 }
    }

    /// Returns the sub-groups — used when actually applying a split.
    static func splitIntoGroups(
        assets: [CurationAsset],
        temporalThreshold: TimeInterval,
        spatialThreshold: Double,
        mode: SplitMode
    ) -> [[CurationAsset]] {
        guard !assets.isEmpty else { return [] }
        switch mode {
        case .time:
            return clusterByTimeOnly(assets, temporalThreshold: temporalThreshold)
        case .location:
            return clusterByLocationOnly(assets, spatialThreshold: spatialThreshold)
        case .both:
            return clusterByTimeAndLocation(assets, temporalThreshold: temporalThreshold,
                                            spatialThreshold: spatialThreshold,
                                            splitRule: .timeAndLocation)
        }
    }

    // MARK: - Grouping strategies

    private static func clusterByTimeAndLocation(
        _ assets: [CurationAsset],
        temporalThreshold: TimeInterval,
        spatialThreshold: Double,
        maxEventDuration: TimeInterval? = nil,
        splitRule: TimeLocationSplitRule = .timeOrLocation
    ) -> [[CurationAsset]] {
        guard !assets.isEmpty else { return [] }
        let sorted = assets.sorted { $0.timestamp < $1.timestamp }
        var groups: [[CurationAsset]] = [[sorted[0]]]
        var currentGroupStart = sorted[0].timestamp
        var currentCentroid = RunningCoordinateCentroid(first: sorted[0].coordinate)

        for i in 1 ..< sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            let exceedsMaxDuration = maxEventDuration.map {
                curr.timestamp.timeIntervalSince(currentGroupStart) > $0
            } ?? false
            let isSpatialJump: Bool = {
                guard dt > 60,
                      let currCoordinate = curr.coordinate,
                      let centroid = currentCentroid.coordinate
                else { return false }
                return haversine(centroid, currCoordinate) > spatialThreshold
            }()
            let isTimeGap = dt > temporalThreshold
            let shouldSplit: Bool
            switch splitRule {
            case .timeOrLocation:
                shouldSplit = isTimeGap || isSpatialJump || exceedsMaxDuration
            case .timeAndLocation:
                shouldSplit = (isTimeGap && isSpatialJump) || exceedsMaxDuration
            }

            if shouldSplit {
                groups.append([curr])
                currentGroupStart = curr.timestamp
                currentCentroid = RunningCoordinateCentroid(first: curr.coordinate)
            } else {
                groups[groups.count - 1].append(curr)
                currentCentroid.add(curr.coordinate)
            }
        }
        return groups
    }

    private static func clusterByTimeOnly(
        _ assets: [CurationAsset],
        temporalThreshold: TimeInterval,
        maxEventDuration: TimeInterval? = nil
    ) -> [[CurationAsset]] {
        guard !assets.isEmpty else { return [] }
        let sorted = assets.sorted { $0.timestamp < $1.timestamp }
        var groups: [[CurationAsset]] = [[sorted[0]]]
        var currentGroupStart = sorted[0].timestamp

        for i in 1 ..< sorted.count {
            let dt = sorted[i].timestamp.timeIntervalSince(sorted[i - 1].timestamp)
            let exceedsMaxDuration = maxEventDuration.map {
                sorted[i].timestamp.timeIntervalSince(currentGroupStart) > $0
            } ?? false
            if dt > temporalThreshold || exceedsMaxDuration {
                groups.append([sorted[i]])
                currentGroupStart = sorted[i].timestamp
            } else {
                groups[groups.count - 1].append(sorted[i])
            }
        }
        return groups
    }

    private static func clusterByLocationOnly(
        _ assets: [CurationAsset],
        spatialThreshold: Double
    ) -> [[CurationAsset]] {
        guard !assets.isEmpty else { return [] }
        let sorted = assets.sorted { $0.timestamp < $1.timestamp }
        var groups: [[CurationAsset]] = [[sorted[0]]]
        var currentCentroid = RunningCoordinateCentroid(first: sorted[0].coordinate)
        for i in 1 ..< sorted.count {
            let curr = sorted[i]
            let isSpatialJump: Bool = {
                guard let currCoordinate = curr.coordinate,
                      let centroid = currentCentroid.coordinate
                else { return false }
                return haversine(centroid, currCoordinate) > spatialThreshold
            }()
            if isSpatialJump {
                groups.append([curr])
                currentCentroid = RunningCoordinateCentroid(first: curr.coordinate)
            } else {
                groups[groups.count - 1].append(curr)
                currentCentroid.add(curr.coordinate)
            }
        }
        return groups
    }

    // MARK: - Burst detection

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
                let primaryIdx = burstGroup.max(by: { a, b in
                    let assetA = result[a], assetB = result[b]
                    if let urlA = assetA.url, let urlB = assetB.url {
                        let sA = (try? FileManager.default.attributesOfItem(atPath: urlA.path)[.size] as? Int) ?? 0
                        let sB = (try? FileManager.default.attributesOfItem(atPath: urlB.path)[.size] as? Int) ?? 0
                        return sA < sB
                    }
                    let areaA = Int(assetA.pixelSize.width * assetA.pixelSize.height)
                    let areaB = Int(assetB.pixelSize.width * assetB.pixelSize.height)
                    return areaA < areaB
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

    // MARK: - Haversine distance

    private static func haversine(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let R = 6371000.0
        let φ1 = a.latitude * .pi / 180, φ2 = b.latitude * .pi / 180
        let Δφ = (b.latitude - a.latitude) * .pi / 180
        let Δλ = (b.longitude - a.longitude) * .pi / 180
        let x = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
        return R * 2 * atan2(sqrt(x), sqrt(1 - x))
    }

    private struct RunningCoordinateCentroid {
        private var latitudeTotal: Double = 0
        private var longitudeTotal: Double = 0
        private var coordinateCount: Double = 0

        init(first coordinate: CLLocationCoordinate2D?) {
            add(coordinate)
        }

        var coordinate: CLLocationCoordinate2D? {
            guard coordinateCount > 0 else { return nil }
            return CLLocationCoordinate2D(
                latitude: latitudeTotal / coordinateCount,
                longitude: longitudeTotal / coordinateCount
            )
        }

        mutating func add(_ coordinate: CLLocationCoordinate2D?) {
            guard let coordinate else { return }
            latitudeTotal += coordinate.latitude
            longitudeTotal += coordinate.longitude
            coordinateCount += 1
        }
    }
}
