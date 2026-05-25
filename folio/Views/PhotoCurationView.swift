import SwiftUI
import AppKit
import Photos
import CoreLocation

struct PhotoCurationView: View {
    @ObservedObject var store: CurationStore
    @EnvironmentObject var settings: AppSettings
    var onBack: () -> Void

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
            get: { store.exportedMarkdown.map { ExportResult(markdown: $0) } },
            set: { if $0 == nil { store.exportedMarkdown = nil } }
        )) { result in
            ExportSheet(markdown: result.markdown)
        }
        .alert("Export Error", isPresented: Binding(
            get: { store.exportError != nil },
            set: { if !$0 { store.exportError = nil } }
        )) {
            Button("OK") { store.exportError = nil }
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
                Text("\(cluster.selectedCount)/\(cluster.totalCount) selected")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Curation Grid Panel

private struct CurationGridPanel: View {
    @ObservedObject var store: CurationStore

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 160), spacing: 8)]
    @State private var isShowingDetail = false
    @State private var detailIndex = 0

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
                    Spacer()
                    Button("Rename Event") { store.beginRename() }
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.panel)
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(store.visibleAssets.enumerated()), id: \.element.id) { idx, asset in
                        ThumbnailCell(asset: asset,
                            onTap: { store.toggleSelection(assetID: asset.id) },
                            onDoubleTap: { detailIndex = idx; isShowingDetail = true }
                        )
                    }
                }
                .padding(12)
            }
            .background(Theme.background)
        }
        .overlay(alignment: .bottom) {
            if store.isExporting {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.7)
                    Text("Exporting...")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $isShowingDetail) {
            PhotoDetailSheet(store: store, currentIndex: $detailIndex)
        }
    }
}

// MARK: - Thumbnail Cell

private struct ThumbnailCell: View {
    let asset: CurationAsset
    let onTap: () -> Void
    let onDoubleTap: () -> Void

    @State private var thumb: NSImage? = nil
    @State private var locationName: String? = nil

    private var locationText: String {
        if asset.isScreenshot { return "Screenshot" }
        if let name = locationName { return name }
        if asset.coordinate != nil { return "…" }
        return "No GPS"
    }

    private var locationIcon: String {
        if asset.isScreenshot { return "camera.viewfinder" }
        if asset.coordinate != nil { return "location.fill" }
        return "location.slash"
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
                .frame(width: 160, height: 120)
                .clipped()
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
                    Text(asset.timestamp, format: .dateTime.hour().minute())
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
            .frame(width: 160, alignment: .leading)
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
        guard !asset.isScreenshot, locationName == nil, let coord = asset.coordinate else { return }
        Task {
            let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
               let pm = placemarks.first {
                let parts = [pm.locality, pm.administrativeArea]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                locationName = parts.isEmpty
                    ? String(format: "%.3f°, %.3f°", coord.latitude, coord.longitude)
                    : parts.joined(separator: ", ")
            } else {
                locationName = String(format: "%.3f°, %.3f°", coord.latitude, coord.longitude)
            }
        }
    }
}

// MARK: - Photo Detail Sheet

private struct PhotoDetailSheet: View {
    @ObservedObject var store: CurationStore
    @Binding var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    @State private var fullImage: NSImage? = nil

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
                        Text(asset.timestamp,
                             format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
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
        .onAppear { loadFullImage() }
        .onChange(of: currentIndex) { _ in loadFullImage() }
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
}

private struct ExportSheet: View {
    let markdown: String
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
                Spacer()
                Button("Copy & Close") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(markdown, forType: .string)
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
