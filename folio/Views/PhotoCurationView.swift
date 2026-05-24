import SwiftUI
import AppKit
import Photos

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

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 8)]

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
                    ForEach(store.visibleAssets) { asset in
                        ThumbnailCell(asset: asset) {
                            store.toggleSelection(assetID: asset.id)
                        }
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
    }
}

// MARK: - Thumbnail Cell

private struct ThumbnailCell: View {
    let asset: CurationAsset
    let onTap: () -> Void

    @State private var thumb: NSImage? = nil

    var body: some View {
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
            .opacity(asset.isSelected ? 1.0 : 0.5)
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
        }
        .onTapGesture { onTap() }
        .onAppear { loadThumb() }
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
