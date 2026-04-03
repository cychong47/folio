import SwiftUI

struct PostListView: View {
    let onBack: () -> Void
    let onSelect: (PostSummary) -> Void

    @EnvironmentObject var settings: AppSettings
    @State private var posts: [PostSummary] = []
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().opacity(0.4)
            contentArea
        }
        .background(Theme.background)
        .onAppear { loadPosts() }
    }

    private var headerBar: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.callout.weight(.semibold))
                    Text("Back")
                        .font(.callout)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .focusable(false)

            Spacer()

            Text("Browse Posts")
                .font(.headline)

            Spacer()

            Button {
                loadPosts()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isLoading)
            .focusable(false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.panel)
    }

    @ViewBuilder
    private var contentArea: some View {
        if settings.contentPath.isEmpty {
            placeholder("Configure a blog profile in Settings first.")
        } else if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        } else if posts.isEmpty {
            placeholder("No posts found in \(settings.contentPath)")
        } else {
            List(posts) { post in
                PostRowView(post: post)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(post) }
                    .listRowBackground(Theme.background)
                    .listRowSeparatorTint(Color.secondary.opacity(0.2))
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            .listStyle(.plain)
            .background(Theme.background)
            .scrollContentBackground(.hidden)
        }
    }

    private func placeholder(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func loadPosts() {
        guard !settings.contentPath.isEmpty else { return }
        isLoading = true
        let path = settings.contentPath
        DispatchQueue.global(qos: .userInitiated).async {
            let result = PostIndexer.scan(contentPath: path)
            DispatchQueue.main.async {
                posts = result
                isLoading = false
            }
        }
    }
}

// MARK: - Row

private struct PostRowView: View {
    let post: PostSummary

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(post.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if post.isDraft {
                    Text("Draft")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(Self.dateFormatter.string(from: post.date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if !post.categories.isEmpty {
                HStack(spacing: 6) {
                    ForEach(post.categories, id: \.self) { cat in
                        Text(cat)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.chipBg)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }
}
