import SwiftUI

struct WelcomeView: View {
    var isDragTargeted: Bool = false
    @EnvironmentObject var pendingPost: PendingPost
    @State private var showCancelConfirm = false

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
                    Text(isDragTargeted
                         ? "Drop to start a new post"
                         : "Drag photos here to create a Hugo post")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)

                    if !isDragTargeted {
                        Button("New Post") { startTextPost() }
                            .buttonStyle(.plain)
                            .font(.callout)
                            .foregroundStyle(Theme.accent)
                            .padding(.top, 4)
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

            if pendingPost.lastPublished != nil {
                VStack {
                    Spacer()
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
