import Foundation
import SwiftUI
import AppKit
import ImageIO
import CoreImage

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
    @Published var sourceFolder: URL? = nil

    var activeCluster: EventCluster? {
        guard clusters.indices.contains(selectedClusterIndex) else { return nil }
        return clusters[selectedClusterIndex]
    }

    var visibleAssets: [CurationAsset] {
        guard let cluster = activeCluster else { return [] }
        // Show only stack primaries (or unstacked photos), plus all stacked when expanded
        // For simplicity in Phase 1, show all assets
        return cluster.assets
    }

    func ingest(from folder: URL) async {
        isIngesting = true
        ingestProgress = (0, 0)
        sourceFolder = folder
        let assets = await MetadataIngestionService.scan(folder: folder) { done, total in
            self.ingestProgress = (done, total)
        }
        let clustered = ClusteringEngine.cluster(assets: assets)
        clusters = clustered
        selectedClusterIndex = 0
        focusedAssetIndex = 0
        isIngesting = false
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

    func commitRename() {
        let trimmed = pendingRename.trimmingCharacters(in: .whitespaces)
        guard clusters.indices.contains(selectedClusterIndex), !trimmed.isEmpty else {
            isRenaming = false; return
        }
        clusters[selectedClusterIndex].name = trimmed
        isRenaming = false
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

        do {
            let eventSlug = cluster.name
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.union(.init(charactersIn: "-")).inverted)
                .joined(separator: "-")
                .components(separatedBy: "-")
                .filter { !$0.isEmpty }
                .joined(separator: "-")

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

            for (i, asset) in selected.enumerated() {
                let seq = String(format: "%02d", i + 1)
                let ext = asset.url.pathExtension.lowercased() == "heic" ? "jpg" : asset.url.pathExtension.lowercased()
                let filename = "\(dateStr)-\(eventSlug)-\(seq).\(ext)"
                let destURL = base.appendingPathComponent(filename)

                // Resize + strip EXIF
                if let maxDim, let resized = resized(url: asset.url, maxLongEdge: maxDim) {
                    let final = stripExif ? stripped(data: resized, url: asset.url) ?? resized : resized
                    try final.write(to: destURL)
                } else if stripExif, let s = stripped(url: asset.url) {
                    try s.write(to: destURL)
                } else {
                    try FileManager.default.copyItem(at: asset.url, to: destURL)
                }

                lines.append("![](\(prefixWithSlash)\(filename))")
            }

            exportedMarkdown = lines.joined(separator: "\n")
        } catch {
            exportError = error.localizedDescription
        }
        isExporting = false
    }

    // MARK: - Private helpers (copied from PhotoExporter to avoid circular deps)

    private func stripped(data: Data, url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return reEncode(source: source, url: url)
    }

    private func stripped(url: URL) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return reEncode(source: source, url: url)
    }

    private func reEncode(source: CGImageSource, url: URL) -> Data? {
        guard let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let uti: CFString = (url.pathExtension.lowercased() == "png" ? "public.png" : "public.jpeg") as CFString
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, uti, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, raw, [
            kCGImageDestinationLossyCompressionQuality: 0.92,
            kCGImageMetadataShouldExcludeGPS: true
        ] as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    private func resized(url: URL, maxLongEdge: Int) -> Data? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let raw = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let w = raw.width, h = raw.height
        guard max(w, h) > maxLongEdge else { return nil }
        let scale = CGFloat(maxLongEdge) / CGFloat(max(w, h))
        let nw = Int((CGFloat(w) * scale).rounded())
        let nh = Int((CGFloat(h) * scale).rounded())
        guard let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.draw(raw, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        guard let out = ctx.makeImage() else { return nil }
        let data = NSMutableData()
        let uti: CFString = (url.pathExtension.lowercased() == "png" ? "public.png" : "public.jpeg") as CFString
        guard let dest = CGImageDestinationCreateWithData(data, uti, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, out, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        CGImageDestinationFinalize(dest)
        return data as Data
    }
}
