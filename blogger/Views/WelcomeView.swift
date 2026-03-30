import SwiftUI
import Photos

struct WelcomeView: View {
    var isDragTargeted: Bool = false
    @EnvironmentObject var pendingPost: PendingPost
    @State private var showCancelConfirm = false
    @State private var photosStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                // Icon in a soft circle, like Things' onboarding
                ZStack {
                    Circle()
                        .fill(isDragTargeted ? Theme.accent.opacity(0.12) : Theme.panel)
                        .frame(width: 100, height: 100)
                    Image(systemName: isDragTargeted ? "photo.badge.plus" : "photo.on.rectangle.angled")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(isDragTargeted ? Theme.accent : Color.secondary)
                }
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)

                VStack(spacing: 6) {
                    Text("Blogger")
                        .font(.title2.weight(.semibold))
                    if isDragTargeted {
                        Text("Drop to start a new post")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 0) {
                            Text("Drag photos here, or ")
                            Button("New Post") { startTextPost() }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.accent)
                                .focusable(false)
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: isDragTargeted)
            }
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

    private func startTextPost() {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let title = f.string(from: Date())
        pendingPost.title = title
        pendingPost.slug = SlugGenerator.slugify(title)
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
            return "Grant Photos access so Blogger can detect the correct date for screenshots and downloaded images."
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
