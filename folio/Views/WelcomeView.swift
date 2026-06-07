import SwiftUI
import Photos

struct WelcomeView: View {
    var isDragTargeted: Bool = false
    var hasCurationSession: Bool = false
    var onBrowse: (() -> Void)? = nil
    var onCurate: (() -> Void)? = nil
    var onResumeCuration: (() -> Void)? = nil
    @EnvironmentObject var pendingPost: PendingPost
    @State private var showCancelConfirm = false
    @State private var photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 34) {
                Text("Photolog")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.primary)

                LazyVGrid(columns: actionColumns, spacing: 18) {
                    DropActionTile(isTargeted: isDragTargeted)

                    WelcomeActionTile(
                        title: "New Post",
                        subtitle: "Start writing",
                        systemImage: "square.and.pencil",
                        action: startTextPost
                    )
                    .keyboardShortcut("n", modifiers: .command)

                    WelcomeActionTile(
                        title: "Browse Posts",
                        subtitle: "Edit existing",
                        systemImage: "doc.text.magnifyingglass",
                        action: { onBrowse?() }
                    )
                    .keyboardShortcut("b", modifiers: .command)

                    WelcomeActionTile(
                        title: "Curate Photos",
                        subtitle: hasCurationSession ? "Load new range" : "Build events",
                        systemImage: "rectangle.stack.badge.person.crop",
                        action: { onCurate?() }
                    )
                    .keyboardShortcut("k", modifiers: .command)
                }
                .frame(maxWidth: 660)

                if hasCurationSession {
                    Button {
                        onResumeCuration?()
                    } label: {
                        Label("Resume Curation", systemImage: "arrow.uturn.forward.circle")
                    }
                    .buttonStyle(.borderless)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Theme.accent)
                    .focusable(false)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isDragTargeted ? Theme.accent : Color.clear,
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .padding(20)
                    .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
            )

            VStack {
                Spacer()
                if photosStatus != .authorized && photosStatus != .limited {
                    PhotosAccessBanner(status: photosStatus) {
                        photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    }
                }
                if pendingPost.lastPublished != nil {
                    Button("Cancel last post") { showCancelConfirm = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.callout)
                        .padding(.bottom, 20)
                }
            }
        }
        .confirmationDialog("Cancel last post?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
            Button("Delete Files", role: .destructive) { cancelLastPost() }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("The markdown file and imported images will be permanently deleted.")
        }
    }

    private var actionColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 140, maximum: 300), spacing: 18),
            GridItem(.flexible(minimum: 140, maximum: 300), spacing: 18)
        ]
    }

    private func startTextPost() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        pendingPost.slug = f.string(from: Date())
    }

    private func cancelLastPost() {
        guard let last = pendingPost.lastPublished else { return }
        let fm = FileManager.default
        try? fm.removeItem(at: last.markdownURL)
        for url in last.imageURLs {
            try? fm.removeItem(at: url)
        }
        pendingPost.lastPublished = nil
    }
}

private struct DropActionTile: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "photo.on.rectangle.angled")
                .font(.system(size: 42, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isTargeted ? Theme.accent : Color.secondary)
                .frame(height: 48)
            VStack(spacing: 3) {
                Text(isTargeted ? "Drop Photos" : "Drag Photos")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(isTargeted ? "Release to import" : "Drop anywhere")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isTargeted ? Theme.accent.opacity(0.12) : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    isTargeted ? Theme.accent : Color.secondary.opacity(0.12),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [8, 4] : [])
                )
        )
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Drag Photos. Drop photos anywhere in the window.")
    }
}

private struct WelcomeActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Theme.accent)
                    .frame(height: 48)
                VStack(spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding(.horizontal, 18)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

// MARK: - Photos Access Banner

private struct PhotosAccessBanner: View {
    let status: PHAuthorizationStatus
    let onStatusChanged: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.circle")
                .foregroundStyle(Theme.accent)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(actionLabel) { performAction() }
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.panel)
    }

    private var message: String {
        switch status {
        case .denied, .restricted:
            return "Photos access is denied. Enable it in System Settings → Privacy & Security → Photos to detect screenshot dates automatically."
        default:
            return "Grant Photos access so Photolog can detect the correct date for screenshots and downloaded images."
        }
    }

    private var actionLabel: String {
        switch status {
        case .denied, .restricted: return "Open Settings"
        default: return "Grant Access"
        }
    }

    private func performAction() {
        switch status {
        case .denied, .restricted:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!)
        default:
            Task {
                await PhotoLibraryDate.requestAuthorization()
                onStatusChanged()
            }
        }
    }
}
