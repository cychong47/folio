import SwiftUI
import AppKit

struct PhotoStripView: View {
    let photos: [ExportedPhoto]
    let orphanedPaths: Set<String>
    let onRemove: (ExportedPhoto) -> Void
    let onAddPhoto: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                if photos.isEmpty {
                    emptyState
                } else {
                    ForEach(photos) { photo in
                        PhotoStripCell(
                            photo: photo,
                            isOrphaned: orphanedPaths.contains(photo.markdownPath),
                            onRemove: { onRemove(photo) }
                        )
                    }
                    addButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(height: 96)
        .background(Theme.panel)
    }

    // Shown when photos array is empty
    private var emptyState: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.secondary.opacity(0.3),
                              style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                .frame(width: 260, height: 80)
                .overlay(
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundStyle(.secondary)
                        Text("Drop photos here to add more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                )
            addButton
        }
    }

    private var addButton: some View {
        Button(action: onAddPhoto) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 80, height: 80)
                .background(Theme.card)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Theme.accent.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                )
        }
        .buttonStyle(.plain)
        .help("Add photos…")
    }
}

// MARK: - Single thumbnail cell

struct PhotoStripCell: View {
    let photo: ExportedPhoto
    let isOrphaned: Bool
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailContent
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)
                .opacity(isOrphaned ? 0.4 : 1.0)

            if isHovered {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Color.black.opacity(0.55))
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
                .transition(.opacity)
            }
        }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Remove Photo", role: .destructive, action: onRemove)
        }
        .accessibilityLabel(photo.isVideo ? "Video: \(photo.filename)" : "Photo: \(photo.filename)")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Remove") { onRemove() }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if photo.isVideo {
            ZStack {
                Color.black.opacity(0.55)
                VStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.white.opacity(0.85))
                    Text(photo.filename)
                        .font(.system(size: 8))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 4)
                }
            }
        } else if let img = NSImage(contentsOf: photo.localURL) {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Theme.card
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
