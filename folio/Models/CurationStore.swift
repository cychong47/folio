import Foundation
import SwiftUI
import AppKit
import ImageIO
import CoreImage
import Photos

@MainActor
class CurationStore: ObservableObject {
    @Published var clusters: [EventCluster] = []
    @Published var selectedClusterIndex: Int = 0
    @Published var focusedAssetIndex: Int = 0
    @Published var isIngesting: Bool = false
    @Published var ingestProgress: (Int, Int) = (0, 0)
    @Published var isRenaming: Bool = false
    @Published var pendingRename: String = ""
    @Published var exportedMarkdown: String? = nil
    @Published var isExporting: Bool = false
    @Published var exportError: String? = nil
    @Published var dateRange: (start: Date, end: Date)? = nil
    @Published var lastFetchCount: Int = 0    // date-range count
    @Published var lastLibraryTotal: Int = 0  // total library count (no filter)
    @Published var lastAuthStatus: String = ""

    var dateRangeLabel: String {
        guard let r = dateRange else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        if Calendar.current.isDate(r.start, inSameDayAs: r.end) {
            return f.string(from: r.start)
        }
        return "\(f.string(from: r.start)) – \(f.string(from: r.end))"
    }

    var activeCluster: EventCluster? {
        guard clusters.indices.contains(selectedClusterIndex) else { return nil }
        return clusters[selectedClusterIndex]
    }

    var visibleAssets: [CurationAsset] {
        guard let cluster = activeCluster else { return [] }
        // Show only stack primaries (or unstacked photos), plus all stacked when expanded
        // For simplicity in Phase 1, show all assets
        return cluster.assets.sorted { $0.timestamp < $1.timestamp }
    }

    func ingest(startDate: Date, endDate: Date) async {
        isIngesting = true
        ingestProgress = (0, 0)
        lastFetchCount = 0
        lastLibraryTotal = 0
        lastAuthStatus = ""
        dateRange = (start: startDate, end: endDate)

        // Check auth — all PhotoKit calls stay on the MainActor (avoids thread-hop issues)
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        lastAuthStatus = authStatusLabel(status)
        guard status == .authorized || status == .limited else {
            isIngesting = false
            return
        }

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: startDate)
        let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
        let opts = PHFetchOptions()
        opts.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            dayStart as CVarArg, dayEnd as CVarArg
        )
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        // Run on a GCD thread. requestAuthorization is called first — it does more than
        // authorizationStatus: it opens the XPC session with photolibraryd. Skipping it
        // and using authorizationStatus alone leaves the session unopened, so fetchAssets
        // silently returns 0 even when TCC reports "Authorized".
        let (libraryTotal, result): (Int, PHFetchResult<PHAsset>) =
            await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async {
                    let sema = DispatchSemaphore(value: 0)
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in sema.signal() }
                    sema.wait()

                    let all = PHAsset.fetchAssets(with: .image, options: nil)
                    let range = PHAsset.fetchAssets(with: .image, options: opts)
                    cont.resume(returning: (all.count, range))
                }
            }
        lastLibraryTotal = libraryTotal
        let total = result.count

        // Build CurationAsset array; yield every 10 items so the progress bar updates
        var assets: [CurationAsset] = []
        assets.reserveCapacity(total)
        for i in 0 ..< total {
            let ph = result.object(at: i)
            let coord = ph.location.map {
                CLLocationCoordinate2D(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            }
            assets.append(CurationAsset(
                phAsset: ph, url: nil,
                timestamp: ph.creationDate ?? Date(),
                captureTimeZone: nil,
                coordinate: coord,
                pixelSize: CGSize(width: ph.pixelWidth, height: ph.pixelHeight),
                isScreenshot: ph.mediaSubtypes.contains(.photoScreenshot),
                isFavorite: ph.isFavorite
            ))
            if (i + 1) % 10 == 0 || i == total - 1 {
                ingestProgress = (i + 1, total)
                await Task.yield()
            }
        }

        lastFetchCount = assets.count
        clusters = ClusteringEngine.cluster(assets: assets)
        selectedClusterIndex = 0
        focusedAssetIndex = 0
        isIngesting = false
    }

    private func authStatusLabel(_ status: PHAuthorizationStatus) -> String {
        switch status {
        case .authorized:    return "Authorized"
        case .limited:       return "Limited"
        case .denied:        return "Denied"
        case .restricted:    return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default:    return "Unknown (\(status.rawValue))"
        }
    }

    func toggleSelection(assetID: UUID) {
        guard clusters.indices.contains(selectedClusterIndex) else { return }
        if let i = clusters[selectedClusterIndex].assets.firstIndex(where: { $0.id == assetID }) {
            clusters[selectedClusterIndex].assets[i].isSelected.toggle()
        }
    }

    func selectAll() {
        guard clusters.indices.contains(selectedClusterIndex) else { return }
        let allSelected = clusters[selectedClusterIndex].assets.allSatisfy(\.isSelected)
        for i in clusters[selectedClusterIndex].assets.indices {
            clusters[selectedClusterIndex].assets[i].isSelected = !allSelected
        }
    }

    func beginRename() {
        guard let cluster = activeCluster else { return }
        pendingRename = cluster.name
        isRenaming = true
    }

    func applySplit(at clusterIndex: Int, temporalThreshold: TimeInterval, spatialThreshold: Double, mode: SplitMode) {
        guard clusters.indices.contains(clusterIndex) else { return }
        let original = clusters[clusterIndex]
        let groups = ClusteringEngine.splitIntoGroups(
            assets: original.assets,
            temporalThreshold: temporalThreshold,
            spatialThreshold: spatialThreshold,
            mode: mode
        )
        guard groups.count > 1 else { return }
        let newClusters = groups.enumerated().map { (i, group) -> EventCluster in
            let dates = group.map(\.timestamp)
            return EventCluster(
                name: "\(original.name) – \(i + 1)",
                assets: group,
                startDate: dates.min() ?? Date(),
                endDate: dates.max() ?? Date()
            )
        }
        clusters.remove(at: clusterIndex)
        clusters.insert(contentsOf: newClusters, at: min(clusterIndex, clusters.count))
        clusters.sort { $0.startDate < $1.startDate }
        if let firstIdx = clusters.firstIndex(where: { $0.id == newClusters[0].id }) {
            selectedClusterIndex = firstIdx
        }
    }

    func commitRename() {
        let trimmed = pendingRename.trimmingCharacters(in: .whitespaces)
        guard clusters.indices.contains(selectedClusterIndex), !trimmed.isEmpty else {
            isRenaming = false; return
        }
        clusters[selectedClusterIndex].name = trimmed
        isRenaming = false
    }

    func toggleFavorite(assetID: UUID) async {
        guard let (ci, ai) = findAsset(id: assetID),
              let phAsset = clusters[ci].assets[ai].phAsset else { return }
        let newValue = !clusters[ci].assets[ai].isFavorite
        await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest(for: phAsset).isFavorite = newValue
            }) { _, _ in cont.resume() }
        }
        // Re-locate in case clusters mutated during the await
        if let (ci2, ai2) = findAsset(id: assetID) {
            clusters[ci2].assets[ai2].isFavorite = newValue
        }
    }

    private func findAsset(id: UUID) -> (Int, Int)? {
        for (ci, cluster) in clusters.enumerated() {
            if let ai = cluster.assets.firstIndex(where: { $0.id == id }) {
                return (ci, ai)
            }
        }
        return nil
    }

    func export(settings: AppSettings) async {
        guard let cluster = activeCluster else { return }
        isExporting = true
        exportError = nil
        let selected = cluster.assets.filter(\.isSelected)
        guard !selected.isEmpty else {
            exportError = "No photos selected in \"\(cluster.name)\"."
            isExporting = false
            return
        }

        let rawPath = settings.staticImagesPath
        guard !rawPath.isEmpty else {
            exportError = "No Static Images Path is configured. Open Settings → Blog and set the path to your Hugo static/images directory."
            isExporting = false
            return
        }
        // Reject paths that are clearly on the read-only system volume
        // (e.g. "/images" instead of "/Users/…/blog/static/images").
        let resolvedPath = (rawPath as NSString).expandingTildeInPath
        guard resolvedPath.hasPrefix("/Users") || resolvedPath.hasPrefix("/Volumes") ||
              resolvedPath.hasPrefix("/tmp") || resolvedPath.hasPrefix("/private/tmp") else {
            exportError = "Static Images Path \"\(rawPath)\" looks like a system path. It should point to a folder inside /Users/… — please check Settings \u{2192} Blog."
            isExporting = false
            return
        }

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateStr = formatter.string(from: cluster.startDate)

            var lines: [String] = ["## \(cluster.name) — \(dateStr)", ""]

            let base = URL(fileURLWithPath: settings.staticImagesPath)
            let prefix = settings.imageURLPrefix
            let prefixWithSlash = prefix.hasSuffix("/") ? prefix : prefix + "/"
            let maxDim = settings.activeProfile?.maxImageDimension
            let stripExif = settings.activeProfile?.stripEXIF ?? true

            try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

            for asset in selected {
                if let phAsset = asset.phAsset {
                    // PhotoKit path: write original to temp file, then process
                    let resources = PHAssetResource.assetResources(for: phAsset)
                    guard let resource = resources.first(where: { $0.type == .photo }) ?? resources.first else {
                        continue
                    }
                    let originalFilename = resource.originalFilename
                    let originalExt = (originalFilename as NSString).pathExtension.lowercased()
                    let ext = originalExt == "heic" ? "jpg" : (originalExt.isEmpty ? "jpg" : originalExt)
                    // Preserve original filename; only swap extension when HEIC→JPEG
                    let baseName = (originalFilename as NSString).deletingPathExtension
                        .replacingOccurrences(of: " ", with: "_")
                    let filename = "\(baseName).\(ext)"
                    let destURL = base.appendingPathComponent(filename)
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString + "." + originalExt)

                    try await writePHAssetResource(resource, to: tempURL)

                    defer { try? FileManager.default.removeItem(at: tempURL) }

                    if let maxDim, let resized = resized(url: tempURL, maxLongEdge: maxDim) {
                        let final = stripExif ? stripped(data: resized, url: tempURL) ?? resized : resized
                        try final.write(to: destURL)
                    } else if stripExif, let s = stripped(url: tempURL) {
                        try s.write(to: destURL)
                    } else {
                        try FileManager.default.copyItem(at: tempURL, to: destURL)
                    }

                    lines.append("![](\(prefixWithSlash)\(filename))")

                } else if let url = asset.url {
                    // File system path — use original filename, swap ext only for HEIC
                    let originalExt = url.pathExtension.lowercased()
                    let ext = originalExt == "heic" ? "jpg" : (originalExt.isEmpty ? "jpg" : originalExt)
                    let baseName = url.deletingPathExtension().lastPathComponent
                        .replacingOccurrences(of: " ", with: "_")
                    let filename = "\(baseName).\(ext)"
                    let destURL = base.appendingPathComponent(filename)

                    if let maxDim, let resized = resized(url: url, maxLongEdge: maxDim) {
                        let final = stripExif ? stripped(data: resized, url: url) ?? resized : resized
                        try final.write(to: destURL)
                    } else if stripExif, let s = stripped(url: url) {
                        try s.write(to: destURL)
                    } else {
                        try FileManager.default.copyItem(at: url, to: destURL)
                    }

                    lines.append("![](\(prefixWithSlash)\(filename))")
                }
            }

            exportedMarkdown = lines.joined(separator: "\n")
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
    }

    // MARK: - Private helpers

    private func writePHAssetResource(_ resource: PHAssetResource, to url: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true
            PHAssetResourceManager.default().writeData(for: resource, toFile: url, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func stripped(data: Data, url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return reEncode(source: source, url: url)
    }

    private func stripped(url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return reEncode(source: source, url: url)
    }

    /// Bakes EXIF orientation into pixel data using CIImage so the tag can be
    /// safely dropped when re-encoding. Mirrors PhotoExporter.orientationCorrected.
    private func orientationCorrected(_ cgImage: CGImage, from source: CGImageSource) -> CGImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let raw = props[kCGImagePropertyOrientation as String] as? UInt32,
              let orientation = CGImagePropertyOrientation(rawValue: raw),
              orientation != .up else { return cgImage }
        let ci = CIImage(cgImage: cgImage).oriented(orientation)
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        return ctx.createCGImage(ci, from: ci.extent) ?? cgImage
    }

    private func reEncode(source: CGImageSource, url: URL) -> Data? {
        guard let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let cgImage = orientationCorrected(raw, from: source)
        let uti: CFString = (url.pathExtension.lowercased() == "png" ? "public.png" : "public.jpeg") as CFString
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cgImage, [
            kCGImageDestinationLossyCompressionQuality: 0.92,
            kCGImageMetadataShouldExcludeGPS: true
        ] as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    private func resized(url: URL, maxLongEdge: Int) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        // Bake orientation before measuring — a 90°-rotated source has swapped w/h
        let cgImage = orientationCorrected(raw, from: source)
        let w = cgImage.width, h = cgImage.height
        guard max(w, h) > maxLongEdge else { return nil }
        let scale = CGFloat(maxLongEdge) / CGFloat(max(w, h))
        let nw = Int((CGFloat(w) * scale).rounded())
        let nh = Int((CGFloat(h) * scale).rounded())
        guard let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        guard let out = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        let uti: CFString = (url.pathExtension.lowercased() == "png" ? "public.png" : "public.jpeg") as CFString
        guard let dest = CGImageDestinationCreateWithData(data, uti, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(dest)
        return data as Data
    }
}
