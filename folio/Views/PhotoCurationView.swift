import SwiftUI
import AppKit
import Photos
import CoreLocation
import MapKit

// MARK: - Geocode cache (shared across all thumbnail cells and detail sheets)

private struct GeocodeResult {
    let locationName: String
    let timeZone: TimeZone?
}

// Key = lat/lon rounded to ~1 km — good enough for timezone lookup
private var _geocodeCache: [String: GeocodeResult] = [:]

private func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> GeocodeResult {
    let key = String(format: "%.2f,%.2f", coordinate.latitude, coordinate.longitude)
    if let cached = _geocodeCache[key] { return cached }

    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    if let pms = try? await CLGeocoder().reverseGeocodeLocation(location), let pm = pms.first {
        let parts = [pm.locality, pm.administrativeArea].compactMap { $0 }.filter { !$0.isEmpty }
        let name = parts.isEmpty
            ? String(format: "%.3f°, %.3f°", coordinate.latitude, coordinate.longitude)
            : parts.joined(separator: ", ")
        let result = GeocodeResult(locationName: name, timeZone: pm.timeZone)
        _geocodeCache[key] = result
        return result
    }
    let fallback = GeocodeResult(
        locationName: String(format: "%.3f°, %.3f°", coordinate.latitude, coordinate.longitude),
        timeZone: nil
    )
    _geocodeCache[key] = fallback
    return fallback
}

/// Format a date in the timezone where the photo was taken (falls back to device timezone).
private func photoLocalTime(_ date: Date, timeZone: TimeZone?, dateStyle: DateFormatter.Style = .none,
                             timeStyle: DateFormatter.Style = .short) -> String {
    let f = DateFormatter()
    f.dateStyle = dateStyle
    f.timeStyle = timeStyle
    f.timeZone = timeZone ?? .current
    return f.string(from: date)
}

private enum ViewMode: Hashable { case grid, map }

private let splitPalette: [Color] = [
    Color(red: 0.96, green: 0.33, blue: 0.33),
    Color(red: 0.20, green: 0.60, blue: 0.86),
    Color(red: 0.18, green: 0.76, blue: 0.56),
    Color(red: 0.94, green: 0.65, blue: 0.14),
    Color(red: 0.65, green: 0.35, blue: 0.94),
    Color(red: 0.24, green: 0.72, blue: 0.29),
    Color(red: 0.96, green: 0.43, blue: 0.72),
    Color(red: 0.45, green: 0.67, blue: 0.89),
]

private struct AssetPin: Identifiable {
    let id: UUID
    let index: Int          // position in store.visibleAssets
    let coordinate: CLLocationCoordinate2D
}

struct PhotoCurationView: View {
    @ObservedObject var store: CurationStore
    @EnvironmentObject var settings: AppSettings
    var onBack: () -> Void
    var onCreatePost: ((String, Date) -> Void)? = nil

    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showDatePicker = false

    var body: some View {
        ZStack {
            if store.isIngesting {
                ingestionOverlay
            } else if store.clusters.isEmpty {
                emptyState
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    EventNavigatorPanel(store: store)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                } detail: {
                    CurationGridPanel(store: store)
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
            }
            ToolbarItem(placement: .principal) {
                if !store.dateRangeLabel.isEmpty {
                    Text(store.dateRangeLabel)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await store.export(settings: settings) } }) {
                    Label("Export Event", systemImage: "square.and.arrow.up")
                }
                .disabled(store.activeCluster?.selectedCount == 0 || store.isExporting)
                .keyboardShortcut("e", modifiers: .command)
            }
        }
        .sheet(isPresented: $store.isRenaming) {
            RenameSheet(store: store)
        }
        .sheet(item: Binding(
            get: { store.exportedMarkdown.map {
                ExportResult(markdown: $0, date: store.activeCluster?.startDate ?? Date())
            } },
            set: { if $0 == nil { store.exportedMarkdown = nil } }
        )) { result in
            ExportSheet(markdown: result.markdown, date: result.date, onCreatePost: onCreatePost)
        }
        .alert("Export Error", isPresented: Binding(
            get: { store.exportError != nil },
            set: { if !$0 { store.exportError = nil } }
        )) {
            Button("OK") { store.exportError = nil }
            if store.exportError?.contains("Settings") == true {
                Button("Open Settings") {
                    store.exportError = nil
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
            }
        } message: {
            Text(store.exportError ?? "")
        }
    }

    private var ingestionOverlay: some View {
        VStack(spacing: 20) {
            ProgressView(value: Double(store.ingestProgress.0), total: max(1, Double(store.ingestProgress.1)))
                .progressViewStyle(.linear)
                .frame(width: 240)
            Text("Scanning \(store.ingestProgress.0) of \(store.ingestProgress.1) photos...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.secondary)
            Text("No photos found")
                .font(.title3.weight(.medium))
            if !store.dateRangeLabel.isEmpty {
                Text("Searched: \(store.dateRangeLabel)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Auth: \(store.lastAuthStatus)  ·  Library: \(store.lastLibraryTotal) photos  ·  In range: \(store.lastFetchCount)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .padding(.bottom, 4)
                if store.lastLibraryTotal == 0 && !store.lastAuthStatus.isEmpty {
                    Text("Your Photos library on this Mac is empty. Open Photos.app and let it sync from iCloud, or connect your iPhone to import photos first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
            }
            Button("Try Different Dates") { showDatePicker = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .sheet(isPresented: $showDatePicker) {
            DateRangePickerView(isPresented: $showDatePicker) { start, end in
                Task { await store.ingest(startDate: start, endDate: end) }
            }
        }
    }
}

// MARK: - Event Navigator Panel

private struct EventNavigatorPanel: View {
    @ObservedObject var store: CurationStore

    var body: some View {
        List(store.clusters.indices, id: \.self, selection: Binding(
            get: { store.selectedClusterIndex },
            set: { store.selectedClusterIndex = $0 ?? 0 }
        )) { idx in
            EventRow(cluster: store.clusters[idx])
                .tag(idx)
        }
        .listStyle(.sidebar)
        .background(Theme.panel)
    }
}

private struct EventRow: View {
    let cluster: EventCluster

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cluster.name)
                .font(.headline)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(cluster.startDate, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                Text(cluster.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(cluster.totalCount) photos")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if cluster.selectedCount > 0 {
                    Text("· \(cluster.selectedCount) selected")
                        .font(.caption2)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Curation Grid Panel

private struct CurationGridPanel: View {
    @ObservedObject var store: CurationStore
    @EnvironmentObject var settings: AppSettings

    @State private var thumbSize: CGFloat = 160
    @State private var isShowingDetail = false
    @State private var detailIndex = 0
    @State private var viewMode: ViewMode = .grid

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbSize, maximum: thumbSize), spacing: 8)]
    }

    @State private var isSplitting = false
    @State private var splitMode: SplitMode = .time
    @State private var splitTemporalMinutes: Double = 90
    @State private var splitSpatialMeters: Double = 500
    @State private var splitAssignments: [UUID: Int] = [:]

    private var groupCounts: [Int] {
        guard let cluster = store.activeCluster, !splitAssignments.isEmpty else { return [] }
        let n = (splitAssignments.values.max() ?? 0) + 1
        var counts = Array(repeating: 0, count: n)
        for asset in cluster.assets {
            if let g = splitAssignments[asset.id] { counts[g] += 1 }
        }
        return counts
    }

    private func updateSplitAssignments() {
        guard let cluster = store.activeCluster, !cluster.assets.isEmpty else {
            splitAssignments = [:]
            return
        }
        let indices = ClusteringEngine.computeGroupAssignments(
            assets: cluster.assets,
            temporalThreshold: splitTemporalMinutes * 60,
            spatialThreshold: splitSpatialMeters,
            mode: splitMode
        )
        var dict: [UUID: Int] = [:]
        for (i, asset) in cluster.assets.enumerated() { dict[asset.id] = indices[i] }
        splitAssignments = dict
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status / action bar
            if let cluster = store.activeCluster {
                HStack(spacing: 12) {
                    Button("Select All") { store.selectAll() }
                        .font(.caption)
                    Text("\(cluster.selectedCount) of \(cluster.totalCount) selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await store.export(settings: settings) }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(cluster.selectedCount == 0 || store.isExporting)
                    Spacer()
                    // Thumbnail size slider
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Slider(value: $thumbSize, in: 100...320)
                            .frame(width: 80)
                            .help("Thumbnail size")
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Picker("", selection: $viewMode) {
                        Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                        Image(systemName: "map").tag(ViewMode.map)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 64)
                    .help(viewMode == .grid ? "Switch to Map" : "Switch to Grid")
                    Button("Rename Event") { store.beginRename() }
                        .font(.caption)
                    Button(isSplitting ? "Cancel Split" : "Split Event") {
                        if isSplitting {
                            isSplitting = false
                            splitAssignments = [:]
                        } else {
                            isSplitting = true
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(isSplitting ? Theme.accent : .primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.panel)
            }

            if viewMode == .grid {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(store.visibleAssets.enumerated()), id: \.element.id) { idx, asset in
                            ThumbnailCell(
                                asset: asset,
                                thumbSize: thumbSize,
                                splitGroupIndex: isSplitting ? splitAssignments[asset.id] : nil,
                                onTap: { store.toggleSelection(assetID: asset.id) },
                                onDoubleTap: { detailIndex = idx; isShowingDetail = true }
                            )
                        }
                    }
                    .padding(12)
                }
                .background(Theme.background)
            } else {
                CurationMapView(store: store) { idx in
                    detailIndex = idx
                    isShowingDetail = true
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                if store.isExporting {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7)
                        Text("Exporting...")
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.vertical, 8)
                }
                if isSplitting {
                    SplitEventPanel(
                        splitMode: $splitMode,
                        temporalMinutes: $splitTemporalMinutes,
                        spatialMeters: $splitSpatialMeters,
                        groupCounts: groupCounts,
                        onApply: {
                            store.applySplit(
                                at: store.selectedClusterIndex,
                                temporalThreshold: splitTemporalMinutes * 60,
                                spatialThreshold: splitSpatialMeters,
                                mode: splitMode
                            )
                            isSplitting = false
                            splitAssignments = [:]
                        },
                        onCancel: {
                            isSplitting = false
                            splitAssignments = [:]
                        }
                    )
                }
            }
        }
        .onChange(of: isSplitting) { val in
            if val { updateSplitAssignments() } else { splitAssignments = [:] }
        }
        .onChange(of: splitMode) { _ in if isSplitting { updateSplitAssignments() } }
        .onChange(of: splitTemporalMinutes) { _ in if isSplitting { updateSplitAssignments() } }
        .onChange(of: splitSpatialMeters) { _ in if isSplitting { updateSplitAssignments() } }
        .onChange(of: store.selectedClusterIndex) { _ in isSplitting = false; splitAssignments = [:] }
        .sheet(isPresented: $isShowingDetail) {
            PhotoDetailSheet(store: store, currentIndex: $detailIndex)
        }
    }
}

// MARK: - Split Event Panel

private struct SplitEventPanel: View {
    @Binding var splitMode: SplitMode
    @Binding var temporalMinutes: Double
    @Binding var spatialMeters: Double
    let groupCounts: [Int]   // per-group photo count; groupCounts.count == number of sub-events
    let onApply: () -> Void
    let onCancel: () -> Void

    private var groupCount: Int { groupCounts.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Split Event")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(groupCount > 1 ? "\(groupCount) sub-events" : "No split")
                    .font(.caption)
                    .foregroundStyle(groupCount > 1 ? Theme.accent : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        groupCount > 1 ? Theme.accent.opacity(0.12) : Color.secondary.opacity(0.1),
                        in: Capsule()
                    )
            }

            Picker("", selection: $splitMode) {
                ForEach(SplitMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if splitMode == .time || splitMode == .both {
                HStack(spacing: 8) {
                    Text("Time gap:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 68, alignment: .leading)
                    Slider(value: $temporalMinutes, in: 5...360)
                    Text(formatMinutes(Int(temporalMinutes.rounded())))
                        .font(.caption.monospacedDigit())
                        .frame(width: 56, alignment: .trailing)
                }
            }

            if splitMode == .location || splitMode == .both {
                HStack(spacing: 8) {
                    Text("Distance:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 68, alignment: .leading)
                    Slider(value: $spatialMeters, in: 100...20000)
                    Text(formatMeters(spatialMeters))
                        .font(.caption.monospacedDigit())
                        .frame(width: 56, alignment: .trailing)
                }
            }

            // Sub-event legend — color chip + photo count per group
            if groupCount > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(0 ..< groupCounts.count, id: \.self) { i in
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(splitPalette[i % splitPalette.count])
                                    .frame(width: 10, height: 10)
                                Text("\(groupCounts[i]) photos")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(splitPalette[i % splitPalette.count].opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }
            }

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                Spacer()
                Button("Apply Split", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .disabled(groupCount <= 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.gray.opacity(0.2)), alignment: .top)
    }

    private func formatMinutes(_ m: Int) -> String {
        if m < 60 { return "\(m) min" }
        let h = m / 60, r = m % 60
        return r > 0 ? "\(h) h \(r) m" : "\(h) h"
    }

    private func formatMeters(_ m: Double) -> String {
        if m < 1000 { return "\(Int(m.rounded())) m" }
        return String(format: "%.1f km", m / 1000)
    }
}

// MARK: - Map View

private struct CurationMapView: View {
    @ObservedObject var store: CurationStore
    let onSelectAsset: (Int) -> Void

    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37, longitude: -100),
        span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 80)
    )
    // Cached — only rebuilt when cluster changes, NOT on every store publish.
    // This prevents MapKit from re-presenting annotations (and tumbling) on
    // unrelated state changes like selection toggles.
    @State private var cachedPins: [AssetPin] = []
    @State private var noGPSCount: Int = 0

    var body: some View {
        if cachedPins.isEmpty && noGPSCount == 0 {
            VStack(spacing: 12) {
                Image(systemName: "location.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No location data")
                    .font(.title3.weight(.medium))
                Text("Photos in this event have no GPS coordinates.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .onAppear { buildPins() }
        } else {
            ZStack(alignment: .bottomTrailing) {
                Map(coordinateRegion: $region, annotationItems: cachedPins) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        PhotoPin { onSelectAsset(pin.index) }
                    }
                }

                if noGPSCount > 0 {
                    Text("\(noGPSCount) photo\(noGPSCount == 1 ? "" : "s") without GPS not shown")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .onAppear { buildPins() }
            .onChange(of: store.selectedClusterIndex) { _ in buildPins() }
        }
    }

    private func buildPins() {
        let assets = store.visibleAssets
        cachedPins = assets.enumerated().compactMap { idx, asset in
            guard let coord = asset.coordinate else { return nil }
            return AssetPin(id: asset.id, index: idx, coordinate: coord)
        }
        noGPSCount = assets.count - cachedPins.count
        fitRegion()
    }

    private func fitRegion() {
        let coords = cachedPins.map(\.coordinate)
        guard !coords.isEmpty else { return }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.005, (lats.max()! - lats.min()!) * 1.5),
            longitudeDelta: max(0.005, (lons.max()! - lons.min()!) * 1.5)
        )
        region = MKCoordinateRegion(center: center, span: span)
    }
}

private struct PhotoPin: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Theme.accent, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thumbnail Cell

private struct ThumbnailCell: View {
    let asset: CurationAsset
    var thumbSize: CGFloat = 160
    var splitGroupIndex: Int? = nil
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    private var thumbHeight: CGFloat { (thumbSize * 0.75).rounded() }

    @State private var thumb: NSImage? = nil
    @State private var geocodeResult: GeocodeResult? = nil

    private var locationText: String {
        if asset.isScreenshot { return "Screenshot" }
        if let name = geocodeResult?.locationName { return name }
        if asset.coordinate != nil { return "…" }
        return "No GPS"
    }

    private var locationIcon: String {
        if asset.isScreenshot { return "camera.viewfinder" }
        if asset.coordinate != nil { return "location.fill" }
        return "location.slash"
    }

    // Format in photo's local timezone so a SF photo shows PST, not KST
    private var timestampText: String {
        photoLocalTime(asset.timestamp, timeZone: geocodeResult?.timeZone)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = thumb {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(Theme.panel)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(.tertiary)
                            )
                    }
                }
                .frame(width: thumbSize, height: thumbHeight)
                .clipped()
                .overlay(alignment: .top) {
                    if let idx = splitGroupIndex {
                        splitPalette[idx % splitPalette.count]
                            .frame(height: 5)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            asset.isSelected ? Theme.accent : Color.clear,
                            lineWidth: 2.5
                        )
                )
                .cornerRadius(6)

                if asset.isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white, Theme.accent)
                        .padding(4)
                }

                if asset.stackID != nil && !asset.isStackPrimary {
                    Image(systemName: "square.stack")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }

                if asset.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                        .padding(4)
                        .background(Color.black.opacity(0.45), in: Circle())
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }

            // Metadata row
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(timestampText)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    Image(systemName: locationIcon)
                        .font(.system(size: 9))
                    Text(locationText)
                        .font(.system(size: 10))
                        .lineLimit(1)
                }
                .foregroundStyle(asset.coordinate != nil || asset.isScreenshot ? .secondary : .tertiary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .frame(width: thumbSize, alignment: .leading)
        }
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onTap() }
        .onAppear {
            loadThumb()
            loadLocationName()
        }
    }

    private func loadThumb() {
        guard thumb == nil else { return }
        if let phAsset = asset.phAsset {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.resizeMode = .fast
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: CGSize(width: 320, height: 240),
                contentMode: .aspectFill,
                options: opts
            ) { image, _ in
                guard let image else { return }
                DispatchQueue.main.async { self.thumb = image }
            }
        } else if let url = asset.url {
            DispatchQueue.global(qos: .userInitiated).async {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                    kCGImageSourceThumbnailMaxPixelSize: 320,
                    kCGImageSourceCreateThumbnailWithTransform: true
                ]
                guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
                else { return }
                let img = NSImage(cgImage: cgImg, size: NSSize(width: cgImg.width, height: cgImg.height))
                DispatchQueue.main.async { thumb = img }
            }
        }
    }

    private func loadLocationName() {
        guard !asset.isScreenshot, geocodeResult == nil, let coord = asset.coordinate else { return }
        Task {
            geocodeResult = await reverseGeocode(coordinate: coord)
        }
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    @ObservedObject var store: CurationStore
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var fullImage: NSImage? = nil
    @State private var geocodeResult: GeocodeResult? = nil

    private var assets: [CurationAsset] { store.visibleAssets }
    private var asset: CurationAsset? {
        assets.indices.contains(currentIndex) ? assets[currentIndex] : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 16) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                if let asset {
                    VStack(spacing: 2) {
                        Text(photoLocalTime(asset.timestamp, timeZone: geocodeResult?.timeZone,
                                            dateStyle: .medium, timeStyle: .short))
                            .font(.callout.weight(.medium))
                        Text(asset.filename)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Favourite toggle (PHAsset only — can't write to Photos for file URLs)
                if let asset, asset.phAsset != nil {
                    Button {
                        Task { await store.toggleFavorite(assetID: asset.id) }
                    } label: {
                        Image(systemName: asset.isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(asset.isFavorite ? Color.red : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(asset.isFavorite ? "Remove from Favorites" : "Add to Favorites")
                    .keyboardShortcut("f", modifiers: [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.panel)

            // Image area
            ZStack {
                Color.black.ignoresSafeArea()
                if let img = fullImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(8)
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom navigation bar
            HStack(spacing: 16) {
                Button {
                    guard currentIndex > 0 else { return }
                    currentIndex -= 1
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(currentIndex == 0)

                Spacer()

                if let asset {
                    Text("\(currentIndex + 1) / \(assets.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        store.toggleSelection(assetID: asset.id)
                    } label: {
                        Label(
                            asset.isSelected ? "Deselect" : "Select for Export",
                            systemImage: asset.isSelected ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(asset.isSelected ? Theme.accent : Color.secondary)
                    }
                    .keyboardShortcut("s", modifiers: [])
                }

                Spacer()

                Button {
                    guard currentIndex < assets.count - 1 else { return }
                    currentIndex += 1
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(currentIndex >= assets.count - 1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.panel)
        }
        .frame(minWidth: 720, minHeight: 560)
        .onAppear { loadFullImage(); loadGeocode() }
        .onChange(of: currentIndex) { _ in loadFullImage(); loadGeocode() }
    }

    private func loadFullImage() {
        fullImage = nil
        if let phAsset = asset?.phAsset {
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .opportunistic
            opts.isNetworkAccessAllowed = true
            PHImageManager.default().requestImage(
                for: phAsset,
                targetSize: CGSize(width: 2400, height: 2400),
                contentMode: .aspectFit,
                options: opts
            ) { image, _ in
                guard let image else { return }
                DispatchQueue.main.async { self.fullImage = image }
            }
        } else if let url = asset?.url {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let img = NSImage(contentsOf: url) else { return }
                DispatchQueue.main.async { self.fullImage = img }
            }
        }
    }

    private func loadGeocode() {
        geocodeResult = nil
        guard let coord = asset?.coordinate else { return }
        Task {
            geocodeResult = await reverseGeocode(coordinate: coord)
        }
    }
}

// MARK: - Sheets

private struct RenameSheet: View {
    @ObservedObject var store: CurationStore

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Event")
                .font(.headline)
            TextField("Event name", text: $store.pendingRename)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
                .onSubmit { store.commitRename() }
            HStack {
                Button("Cancel") { store.isRenaming = false }
                Button("OK") { store.commitRename() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}

private struct ExportResult: Identifiable {
    let id = UUID()
    let markdown: String
    let date: Date
}

private struct ExportSheet: View {
    let markdown: String
    let date: Date
    var onCreatePost: ((String, Date) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exported Markdown")
                .font(.headline)
            ScrollView {
                Text(markdown)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 240)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("Copy Markdown") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(markdown, forType: .string)
                    dismiss()
                }
                Spacer()
                Button("Create New Post") {
                    onCreatePost?(markdown, date)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}
