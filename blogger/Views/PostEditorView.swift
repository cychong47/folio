import SwiftUI
import AppKit

struct PostEditorView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pendingPost: PendingPost

    @State private var showPublishSuccess = false
    @State private var publishedPath = ""
    @State private var publishError: String?
    @State private var showResetConfirm = false
    @State private var newCategoryText = ""
    @State private var showNewCategoryField = false

    private var availableCategories: [String] {
        settings.knownCategories.filter { !pendingPost.categories.contains($0) }
    }

    private var stagingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Blogger/pending", isDirectory: true)
    }

    private var postDate: Date { pendingPost.photos.first?.exifDate ?? Date() }

    private var datePrefix: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: postDate)
    }

    /// Full filename shown to the user and used when publishing
    private var fullFilename: String {
        let slug = pendingPost.slug.isEmpty ? "untitled" : pendingPost.slug
        return "\(datePrefix)-\(slug)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header fields
            VStack(spacing: 8) {
                HStack {
                    Text("Title:")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    TextField("Post title", text: $pendingPost.title)
                        .onChange(of: pendingPost.title) { newValue in
                            pendingPost.slug = SlugGenerator.slugify(newValue)
                            updateFrontmatterTitle(newValue)
                        }
                }
                HStack {
                    Text("Filename:")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Text(datePrefix + "-")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                    TextField("slug", text: $pendingPost.slug)
                        .font(.system(.body, design: .monospaced))
                    Text(".md")
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .center, spacing: 6) {
                    Text("Categories:")
                        .frame(width: 60, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    // Selected category chips
                    ForEach(pendingPost.categories, id: \.self) { cat in
                        HStack(spacing: 3) {
                            Text(cat).font(.caption)
                            Button {
                                pendingPost.categories.removeAll { $0 == cat }
                                updateFrontmatterCategories(pendingPost.categories)
                            } label: {
                                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.15))
                        .cornerRadius(4)
                    }
                    // Add button
                    Menu {
                        ForEach(availableCategories, id: \.self) { cat in
                            Button(cat) {
                                pendingPost.categories.append(cat)
                                updateFrontmatterCategories(pendingPost.categories)
                            }
                        }
                        if !availableCategories.isEmpty { Divider() }
                        Button("New…") { showNewCategoryField = true }
                    } label: {
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    // Inline new category input
                    if showNewCategoryField {
                        TextField("Category name", text: $newCategoryText)
                            .frame(width: 130)
                            .onSubmit {
                                let trimmed = newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !trimmed.isEmpty && !pendingPost.categories.contains(trimmed) {
                                    pendingPost.categories.append(trimmed)
                                    updateFrontmatterCategories(pendingPost.categories)
                                }
                                newCategoryText = ""
                                showNewCategoryField = false
                            }
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            HSplitView {
                // Left: markdown editor (fully editable)
                TextEditor(text: $pendingPost.markdownBody)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 300)

                // Right: photo gallery
                VStack(spacing: 0) {
                    // Staging location info
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.caption2)
                        Text(stagingDirectory.path)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .help(stagingDirectory.path)
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(stagingDirectory)
                        } label: {
                            Image(systemName: "arrow.right.circle")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundStyle(.secondary)
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(pendingPost.photos) { photo in
                                PhotoThumbnailView(photo: photo)
                            }
                        }
                        .padding()
                    }
                }
                .frame(minWidth: 200, maxWidth: 360)
                .background(Color(NSColor.controlBackgroundColor))
            }

            Divider()

            // Footer toolbar
            HStack {
                if let err = publishError {
                    Text(err)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Button("Reset") { showResetConfirm = true }
                    .foregroundStyle(.red)
                Button("Publish") { publish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command, .shift])
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .alert("Post Published", isPresented: $showPublishSuccess) {
            Button("OK") {
                deleteStagingFiles()
                pendingPost.clear()
            }
        } message: {
            Text("Saved to:\n\(publishedPath)")
        }
        .confirmationDialog("Reset post?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                deleteStagingFiles()
                pendingPost.clear()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will discard all photos and text. Staged image files will be deleted.")
        }
        .onAppear { prepopulateMarkdown() }
    }

    private func updateFrontmatterTitle(_ newTitle: String) {
        guard !pendingPost.markdownBody.isEmpty else { return }
        let escaped = newTitle.replacingOccurrences(of: "\"", with: "\\\"")
        // Replace only the title: "..." line inside the frontmatter
        if let range = pendingPost.markdownBody.range(of: #"(?m)^title: ".*"$"#, options: .regularExpression) {
            pendingPost.markdownBody.replaceSubrange(range, with: "title: \"\(escaped)\"")
        }
    }

    private func prepopulateMarkdown() {
        guard !pendingPost.photos.isEmpty, pendingPost.markdownBody.isEmpty else { return }
        let date = pendingPost.photos.first?.exifDate ?? Date()
        pendingPost.markdownBody = MarkdownGenerator.initialMarkdown(
            title: pendingPost.title,
            date: date,
            photos: pendingPost.photos,
            categories: pendingPost.categories
        )
    }

    private func updateFrontmatterCategories(_ categories: [String]) {
        guard !pendingPost.markdownBody.isEmpty else { return }
        let catsStr = categories.map { "\"\($0)\"" }.joined(separator: ", ")
        if let range = pendingPost.markdownBody.range(
            of: #"(?m)^categories: \[.*\]$"#, options: .regularExpression) {
            pendingPost.markdownBody.replaceSubrange(range, with: "categories: [\(catsStr)]")
        }
    }

    private func publish() {
        publishError = nil
        guard settings.isConfigured else {
            publishError = "Configure paths in Settings first."
            return
        }
        guard !pendingPost.slug.isEmpty else {
            publishError = "Filename (slug) cannot be empty."
            return
        }

        let date = pendingPost.photos.first?.exifDate ?? Date()
        do {
            try PhotoExporter.copyPendingToStatic(photos: pendingPost.photos, settings: settings)
            let fileURL = try MarkdownGenerator.write(
                content: pendingPost.markdownBody,
                filename: fullFilename,
                date: date,
                settings: settings
            )
            publishedPath = fileURL.path
            showPublishSuccess = true
            // Staging files are deleted in the alert OK handler after user sees the path
        } catch {
            publishError = error.localizedDescription
        }
    }

    private func deleteStagingFiles() {
        let fm = FileManager.default
        for photo in pendingPost.photos {
            try? fm.removeItem(at: photo.localURL)
        }
        // Remove staging dir if now empty
        if let contents = try? fm.contentsOfDirectory(atPath: stagingDirectory.path),
           contents.isEmpty {
            try? fm.removeItem(at: stagingDirectory)
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: ExportedPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(photo.filename)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            if let image = NSImage(contentsOf: photo.localURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 120)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
    }
}
