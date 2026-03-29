import SwiftUI
import AppKit

struct PostEditorView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pendingPost: PendingPost

    @State private var publishError: String?
    @State private var showResetConfirm = false
    @State private var newCategoryText = ""
    @State private var showNewCategoryField = false
    @State private var newTagText = ""
    @State private var showNewTagField = false
    @State private var newSeriesText = ""
    @State private var showNewSeriesField = false

    private var availableCategories: [String] {
        settings.knownCategories.filter { !pendingPost.categories.contains($0) }
    }

    private var stagingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Blogger/pending", isDirectory: true)
    }

    private var postDate: Date { pendingPost.postDate }

    private var datePrefix: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: postDate)
    }

    private var fullFilename: String {
        let slug = pendingPost.slug.isEmpty ? "untitled" : pendingPost.slug
        return "\(datePrefix)-\(slug)"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().opacity(0.4)
            editorSection
            Divider().opacity(0.4)
            footerSection
        }
        .background(Theme.background)
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

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title
            HStack {
                Text("Title")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("New post title…", text: $pendingPost.title)
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.medium))
                    .onChange(of: pendingPost.title) { newValue in
                        pendingPost.slug = SlugGenerator.slugify(newValue)
                    }
            }

            // Filename
            HStack {
                Text("File")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                HStack(spacing: 0) {
                    Text(datePrefix + "-")
                        .foregroundStyle(.secondary)
                    TextField("slug", text: $pendingPost.slug)
                        .textFieldStyle(.plain)
                    Text(".md")
                        .foregroundStyle(.secondary)
                }
                .font(.system(.callout, design: .monospaced))
            }

            // Date
            HStack {
                Text("Date")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                DatePicker("", selection: Binding(
                    get: { pendingPost.postDate },
                    set: { applyDateOverride($0) }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                Spacer()
            }

            // Blog selector (only when multiple profiles exist)
            if settings.profiles.count > 1 {
                HStack {
                    Text("Blog")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Picker("", selection: Binding(
                        get: { settings.selectedProfileID ?? settings.profiles.first?.id ?? UUID() },
                        set: { settings.selectedProfileID = $0 }
                    )) {
                        ForEach(settings.profiles) { profile in
                            Text(profile.name).tag(profile.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 220)
                    Spacer()
                }
            }

            // Categories
            HStack(alignment: .center, spacing: 8) {
                Text("Categories")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pendingPost.categories, id: \.self) { cat in
                            HStack(spacing: 4) {
                                Text(cat)
                                    .font(.caption.weight(.medium))
                                Button {
                                    pendingPost.categories.removeAll { $0 == cat }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.chipBg)
                            .clipShape(Capsule())
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                Menu {
                    ForEach(availableCategories, id: \.self) { cat in
                        Button(cat) {
                            pendingPost.categories.append(cat)
                        }
                    }
                    if !availableCategories.isEmpty { Divider() }
                    Button("New…") { showNewCategoryField = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent.opacity(0.8))
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22, height: 22)

                if showNewCategoryField {
                    TextField("Category", text: $newCategoryText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.card)
                        .cornerRadius(6)
                        .onSubmit {
                            let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")
                            let trimmed = newCategoryText
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .trimmingCharacters(in: quoteChars)
                            if !trimmed.isEmpty && !pendingPost.categories.contains(trimmed) {
                                pendingPost.categories.append(trimmed)
                            }
                            newCategoryText = ""
                            showNewCategoryField = false
                        }
                }
                Spacer()
            }

            // Tags
            HStack(alignment: .center, spacing: 8) {
                Text("Tags")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(pendingPost.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Text(tag)
                                    .font(.caption.weight(.medium))
                                Button {
                                    pendingPost.tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 7, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.chipBg)
                            .clipShape(Capsule())
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

                Button { showNewTagField = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent.opacity(0.8))
                        .font(.system(size: 17))
                }
                .buttonStyle(.plain)
                .frame(width: 22, height: 22)

                if showNewTagField {
                    TextField("Tag", text: $newTagText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 120)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.card)
                        .cornerRadius(6)
                        .onSubmit {
                            let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && !pendingPost.tags.contains(trimmed) {
                                pendingPost.tags.append(trimmed)
                            }
                            newTagText = ""
                            showNewTagField = false
                        }
                }
                Spacer()
            }

            // Series
            HStack(alignment: .center, spacing: 8) {
                Text("Series")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                if !pendingPost.series.isEmpty {
                    HStack(spacing: 4) {
                        Text(pendingPost.series)
                            .font(.caption.weight(.medium))
                        Button {
                            pendingPost.series = ""
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 7, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.chipBg)
                    .clipShape(Capsule())
                }

                Menu {
                    ForEach(settings.knownSeries.filter { $0 != pendingPost.series }, id: \.self) { s in
                        Button(s) { pendingPost.series = s }
                    }
                    if !settings.knownSeries.filter({ $0 != pendingPost.series }).isEmpty { Divider() }
                    Button("New…") { showNewSeriesField = true }
                } label: {
                    Image(systemName: pendingPost.series.isEmpty ? "plus.circle.fill" : "pencil.circle.fill")
                        .foregroundStyle(Theme.accent.opacity(0.8))
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22, height: 22)

                if showNewSeriesField {
                    TextField("Series name", text: $newSeriesText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .frame(width: 140)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.card)
                        .cornerRadius(6)
                        .onSubmit {
                            let trimmed = newSeriesText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                pendingPost.series = trimmed
                                if !settings.knownSeries.contains(trimmed) {
                                    settings.knownSeries.append(trimmed)
                                }
                            }
                            newSeriesText = ""
                            showNewSeriesField = false
                        }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.background)
    }

    private var editorSection: some View {
        HSplitView {
            // Left: markdown editor
            TextEditor(text: $pendingPost.markdownBody)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 300)
                .scrollContentBackground(.hidden)
                .background(Theme.background)

            // Right: photo gallery
            VStack(spacing: 0) {
                // Staging path bar
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
                        Image(systemName: "arrow.up.right.circle")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .help("Reveal in Finder")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(.secondary)
                .background(Theme.panel)

                Divider().opacity(0.4)

                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(pendingPost.photos) { photo in
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                    .padding(12)
                }
                .background(Theme.panel)
            }
            .frame(minWidth: 200, maxWidth: 360)
        }
    }

    private var footerSection: some View {
        HStack(spacing: 10) {
            if let err = publishError {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                Text(err)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
            Button("Reset") { showResetConfirm = true }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.75))
                .font(.callout)
            Button("Publish") { publish() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .keyboardShortcut(.return, modifiers: [.command, .shift])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    // MARK: - Logic (unchanged)

    private func prepopulateMarkdown() {
        guard !pendingPost.photos.isEmpty, pendingPost.markdownBody.isEmpty else { return }
        pendingPost.markdownBody = MarkdownGenerator.initialBody(photos: pendingPost.photos)
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
        let date = pendingPost.postDate
        do {
            let imageURLs = try PhotoExporter.copyPendingToStatic(photos: pendingPost.photos, settings: settings)
            let fullContent = MarkdownGenerator.frontmatter(
                title: pendingPost.title,
                date: date,
                categories: pendingPost.categories,
                tags: pendingPost.tags,
                series: pendingPost.series
            ) + "\n" + pendingPost.markdownBody
            let mdURL = try MarkdownGenerator.write(
                content: fullContent,
                filename: fullFilename,
                date: date,
                settings: settings
            )
            pendingPost.lastPublished = PublishedRecord(markdownURL: mdURL, imageURLs: imageURLs)
            deleteStagingFiles()
            pendingPost.clear()
        } catch {
            publishError = error.localizedDescription
        }
    }

    private func applyDateOverride(_ newDate: Date) {
        let fm = FileManager.default
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let newDateStr = f.string(from: newDate)

        var updatedPhotos: [ExportedPhoto] = []
        for photo in pendingPost.photos {
            // Photo filenames are always "YYYY-MM-DD-name.ext" (11-char prefix)
            let rest = photo.filename.count > 11 ? String(photo.filename.dropFirst(11)) : photo.filename
            let newFilename = "\(newDateStr)-\(rest)"
            let newLocalURL = photo.localURL.deletingLastPathComponent()
                .appendingPathComponent(newFilename)

            if photo.localURL.path != newLocalURL.path {
                try? fm.moveItem(at: photo.localURL, to: newLocalURL)
            }

            let newMarkdownPath = buildMarkdownPath(filename: newFilename, date: newDate)
            pendingPost.markdownBody = pendingPost.markdownBody
                .replacingOccurrences(of: photo.markdownPath, with: newMarkdownPath)

            updatedPhotos.append(ExportedPhoto(
                filename: newFilename,
                markdownPath: newMarkdownPath,
                localURL: newLocalURL,
                exifDate: photo.exifDate
            ))
        }

        pendingPost.photos = updatedPhotos
        pendingPost.dateOverride = newDate
    }

    /// Replicates DropTargetView's buildMarkdownPath logic using current settings.
    private func buildMarkdownPath(filename: String, date: Date) -> String {
        let prefix = settings.imageURLPrefix
        let resolvedPrefix = AppSettings.resolveSubpath(prefix, for: date)
        let slash = resolvedPrefix.hasSuffix("/") ? resolvedPrefix : resolvedPrefix + "/"
        let sub = AppSettings.resolveSubpath(settings.staticImagesSubpath, for: date)
        if sub.isEmpty { return "\(slash)\(filename)" }
        let subSlash = sub.hasSuffix("/") ? sub : sub + "/"
        return "\(slash)\(subSlash)\(filename)"
    }

    private func deleteStagingFiles() {
        let fm = FileManager.default
        for photo in pendingPost.photos {
            try? fm.removeItem(at: photo.localURL)
        }
        if let contents = try? fm.contentsOfDirectory(atPath: stagingDirectory.path),
           contents.isEmpty {
            try? fm.removeItem(at: stagingDirectory)
        }
    }
}

// MARK: - Photo Thumbnail

struct PhotoThumbnailView: View {
    let photo: ExportedPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = NSImage(contentsOf: photo.localURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
                    .frame(height: 120)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
            Text(photo.filename)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(10)
        .background(Theme.card)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}
