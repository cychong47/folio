import SwiftUI
import AppKit

// Watches a single file for external writes and fires a debounced callback on the main queue.
// Handles both direct writes and atomic-rename saves (VSCode, Neovim, etc.) by
// watching .write, .rename, and .delete, then re-opening the file after each event
// to track whatever inode is now at the path.
// The 150 ms debounce coalesces rapid events (e.g. mid-write flushes from direct-write
// editors) so onChange fires once per logical save, not once per flush.
private final class FileWatcher: ObservableObject {
    private var source: DispatchSourceFileSystemObject?
    private var debounceTask: Task<Void, Never>?
    private var pendingIgnore = false

    func watch(url: URL, onChange: @escaping () -> Void) {
        stop()
        openAndWatch(url: url, onChange: onChange)
    }

    private func openAndWatch(url: URL, onChange: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        src.setEventHandler { [weak self] in
            guard let self else { return }
            let shouldNotify = !self.pendingIgnore
            self.pendingIgnore = false
            // Re-open after this handler returns to track the new inode
            // if the editor replaced the file via atomic rename.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.source?.cancel()
                self.source = nil
                self.openAndWatch(url: url, onChange: onChange)
            }
            guard shouldNotify else { return }
            // Debounce: cancel any pending notification and wait 150 ms for writes to settle.
            self.debounceTask?.cancel()
            self.debounceTask = Task { @MainActor [weak self] in
                guard let self else { return }
                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else { return }
                onChange()
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    /// Call before writing the file from within the app to skip the next event.
    func ignoreNextChange() { pendingIgnore = true }

    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        source?.cancel()
        source = nil
    }
}

struct PostEditorView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var pendingPost: PendingPost

    @StateObject private var hugoServer = HugoServerManager()
    @StateObject private var fileWatcher = FileWatcher()

    @State private var publishError: String?
    @State private var gitStatus: String?
    @State private var gitSuccess = false
    @State private var showResetConfirm = false
    @State private var titleIsInvalid = false
    @State private var newCategoryText = ""
    @State private var showNewCategoryField = false
    @State private var newTagText = ""
    @State private var showNewTagField = false
    @State private var newSeriesText = ""
    @State private var showNewSeriesField = false
    @State private var previewBody: String = ""
    @State private var previewDebounceTask: Task<Void, Never>? = nil
    @State private var originalSnapshot: String = ""
    /// Staging files queued for deletion on Reset.
    @State private var pendingDeletion: [URL] = []
    /// Paths in `pendingPost.photos` not currently referenced in `markdownBody`.
    @State private var orphanedPaths: Set<String> = []
    @State private var showSaveConfirmation = false
    @State private var saveConfirmationTask: Task<Void, Never>? = nil
    @State private var writingIssues: [WritingIssue] = []
    @State private var writingReviewStatus: String?

    private var availableCategories: [String] {
        settings.knownCategories.filter { !pendingPost.categories.contains($0) }
    }

    private var availableTags: [String] {
        settings.knownTags.filter { !pendingPost.tags.contains($0) }
    }

    private var stagingDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Photolog/pending", isDirectory: true)
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

    private var isReEditing: Bool { pendingPost.existingFileURL != nil }
    private var hasEdits: Bool {
        isReEditing && (pendingPost.title + pendingPost.markdownBody) != originalSnapshot
    }

    private var resetMessage: String {
        if isReEditing {
            return "This will discard your unsaved changes."
        } else if pendingPost.lastPublished != nil {
            return "This will discard all content and delete the saved post files."
        } else {
            return "This will discard all photos and text. Staged image files will be deleted."
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().opacity(0.4)
            photoStripSection
            Divider().opacity(0.4)
            editorSection
            Divider().opacity(0.4)
            footerSection
        }
        .background(Theme.background)
        .overlay(alignment: .top) {
            if showSaveConfirmation {
                Button {
                    hideSaveConfirmation()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                        Text("Post saved successfully")
                            .font(.callout.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
                .help("Dismiss")
            }
        }
        .animation(.easeOut(duration: 0.18), value: showSaveConfirmation)
        .confirmationDialog(isReEditing ? "Discard changes?" : "Reset post?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button(isReEditing ? "Discard Changes" : "Reset", role: .destructive) {
                if isReEditing {
                    // Re-editing: just abandon the session, leave the existing file untouched
                    pendingPost.lastPublished = nil
                } else {
                    if let last = pendingPost.lastPublished {
                        let fm = FileManager.default
                        try? fm.removeItem(at: last.markdownURL)
                        for url in last.imageURLs { try? fm.removeItem(at: url) }
                        pendingPost.lastPublished = nil
                    }
                    deleteStagingFiles()
                }
                pendingPost.clear()
                titleIsInvalid = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(resetMessage)
        }
        .onAppear {
            prepopulateMarkdown()
            previewBody = pendingPost.markdownBody
            originalSnapshot = pendingPost.title + pendingPost.markdownBody
            if let url = pendingPost.existingFileURL {
                fileWatcher.watch(url: url) { reloadBodyFromDisk(url: url) }
            }
        }
        .onDisappear {
            hugoServer.stop()
            previewDebounceTask?.cancel()
            saveConfirmationTask?.cancel()
            fileWatcher.stop()
        }
        .onChange(of: pendingPost.existingFileURL) { url in
            originalSnapshot = pendingPost.title + pendingPost.markdownBody
            if let url {
                fileWatcher.watch(url: url) { reloadBodyFromDisk(url: url) }
            } else {
                fileWatcher.stop()
            }
        }
        .onChange(of: pendingPost.markdownBody) { newValue in
            previewDebounceTask?.cancel()
            previewDebounceTask = Task { @MainActor in
                do {
                    try await Task.sleep(nanoseconds: 300_000_000)
                    previewBody = newValue
                } catch {}
            }
            // Keep photo strip in sync: grey out thumbnails whose refs were manually removed.
            let referenced = MarkdownGenerator.referencedPaths(in: newValue)
            orphanedPaths = Set(pendingPost.photos.map(\.markdownPath)).subtracting(referenced)
        }
    }

    // MARK: - Sections

    private var photoStripSection: some View {
        PhotoStripView(
            photos: pendingPost.photos,
            orphanedPaths: orphanedPaths,
            onRemove: removePhoto,
            onAddPhoto: pickAndAddPhotos
        )
    }

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
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(titleIsInvalid ? Color.red : Color.clear, lineWidth: 1.5)
                            .padding(.horizontal, -4)
                            .padding(.vertical, -2)
                    )
                    .onChange(of: pendingPost.title) { newValue in
                        pendingPost.slug = SlugGenerator.slugify(newValue)
                        if !newValue.isEmpty { titleIsInvalid = false }
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

                Menu {
                    ForEach(availableTags, id: \.self) { tag in
                        Button(tag) {
                            pendingPost.tags.append(tag)
                        }
                    }
                    if !availableTags.isEmpty { Divider() }
                    Button("New…") { showNewTagField = true }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.accent.opacity(0.8))
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)
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

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
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
                    }
                }
                .fixedSize(horizontal: false, vertical: true)

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

    private static let imageRefRegex = try! NSRegularExpression(pattern: #"^!\[\]\(([^)]+)\)\s*$"#)
    private static let videoRefRegex = try! NSRegularExpression(pattern: #"\{\{< video [^>]*src="([^"]+)"[^>]* >\}\}"#)

    private var previewBlocks: [PostPreviewBlock] {
        var blocks: [PostPreviewBlock] = []
        var textLines: [String] = []
        var index = 0

        func flushText() {
            let joined = textLines.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(PostPreviewBlock(id: index, kind: .text(joined)))
                index += 1
            }
            textLines = []
        }

        for line in previewBody.components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..., in: line)
            if let match = Self.imageRefRegex.firstMatch(in: line, range: range),
               let capRange = Range(match.range(at: 1), in: line),
               let photo = pendingPost.photos.first(where: { $0.markdownPath == String(line[capRange]) }) {
                flushText()
                blocks.append(PostPreviewBlock(id: index, kind: .image(photo)))
                index += 1
            } else if let match = Self.videoRefRegex.firstMatch(in: line, range: range),
                      let capRange = Range(match.range(at: 1), in: line),
                      let video = pendingPost.photos.first(where: { $0.markdownPath == String(line[capRange]) && $0.isVideo }) {
                flushText()
                blocks.append(PostPreviewBlock(id: index, kind: .video(video)))
                index += 1
            } else {
                textLines.append(line)
            }
        }
        flushText()
        return blocks
    }

    private var editorSection: some View {
        HSplitView {
            // Left: markdown editor
            TextEditor(text: $pendingPost.markdownBody)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 300, maxWidth: .infinity)
                .scrollContentBackground(.hidden)
                .background(Theme.background)

            // Right: preview panel
            VStack(spacing: 0) {
                // Path bar
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                    let displayPath = pendingPost.existingFileURL?.path ?? stagingDirectory.path
                    Text(displayPath)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .help(displayPath)
                    Spacer()
                    Button {
                        let revealURL = pendingPost.existingFileURL ?? stagingDirectory
                        NSWorkspace.shared.activateFileViewerSelecting([revealURL])
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
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(previewBlocks) { block in
                            switch block.kind {
                            case .text(let content):
                                Text(content.trimmingCharacters(in: .newlines))
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            case .image(let photo):
                                VStack(alignment: .leading, spacing: 6) {
                                    if let img = NSImage(contentsOf: photo.localURL) {
                                        Image(nsImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .cornerRadius(8)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.08))
                                            .frame(height: 100)
                                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                                    }
                                    Text(PostPreviewBlock.mediaCaption(for: photo))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                }
                            case .video(let video):
                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.08))
                                        .frame(height: 100)
                                        .overlay(
                                            Image(systemName: "film")
                                                .font(.title2)
                                                .foregroundStyle(.secondary)
                                        )
                                    Text(PostPreviewBlock.mediaCaption(for: video))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .background(Theme.panel)
            }
            .frame(minWidth: 200, maxWidth: .infinity)

            reviewSidebar
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        }
    }

    private var reviewSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(Theme.accent)
                Text("Revise")
                    .font(.headline)
                Spacer()
                Button {
                    runWritingReview()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Check writing")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Button {
                runWritingReview()
            } label: {
                Label("Check Writing", systemImage: "text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            Divider().opacity(0.4)

            if writingIssues.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: writingReviewStatus == nil ? "text.badge.checkmark" : "checkmark.circle")
                        .font(.title2)
                        .foregroundStyle(writingReviewStatus == nil ? .secondary : Color.green)
                    Text(writingReviewStatus ?? "Run a local writing check for Korean spelling, repeated words, long sentences, and missing image alt text.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(writingIssues) { issue in
                            writingIssueRow(issue)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(Theme.panel)
    }

    private func writingIssueRow(_ issue: WritingIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(issue.kind.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }

            Text(issue.excerpt)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .textSelection(.enabled)

            Text(issue.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let replacement = issue.replacement {
                HStack(spacing: 8) {
                    Text(replacement)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                    Button("Apply") {
                        applyWritingIssue(issue)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(10)
        .background(Theme.card)
        .cornerRadius(8)
    }

    private var footerSection: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                if let err = publishError {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.callout)
                            .padding(.top, 1)
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(err, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Copy error to clipboard")
                        .padding(.top, 1)
                    }
                }
                if let status = gitStatus {
                    HStack(spacing: 4) {
                        Image(systemName: gitSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(gitSuccess ? Color.green : Color.orange)
                            .font(.callout)
                        Text(status)
                            .foregroundStyle(gitSuccess ? Color.green : Color.orange)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            Spacer()
            Button(isReEditing ? (hasEdits ? "Discard Changes" : "Cancel") : "Reset") {
                if isReEditing && !hasEdits {
                    pendingPost.clear()
                } else {
                    showResetConfirm = true
                }
            }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.75))
                .font(.callout)
            Button("Save") {
                guard save() else { return }
                showSavedConfirmation()
            }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .keyboardShortcut("s", modifiers: .command)
            Button("Preview") { previewInBrowser() }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .help(hugoServer.isRunning ? "Save and open post in browser" : "Save, start Hugo server, and open post in browser")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    // MARK: - Logic

    private func showSavedConfirmation() {
        saveConfirmationTask?.cancel()
        showSaveConfirmation = true
        saveConfirmationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            showSaveConfirmation = false
            saveConfirmationTask = nil
        }
    }

    private func hideSaveConfirmation() {
        saveConfirmationTask?.cancel()
        saveConfirmationTask = nil
        showSaveConfirmation = false
    }

    private func runWritingReview() {
        writingIssues = WritingReviewService.review(markdown: pendingPost.markdownBody)
        writingReviewStatus = writingIssues.isEmpty ? "No writing issues found." : nil
    }

    private func applyWritingIssue(_ issue: WritingIssue) {
        let updated = WritingReviewService.apply(issue: issue, to: pendingPost.markdownBody)
        guard updated != pendingPost.markdownBody else { return }
        pendingPost.markdownBody = updated
        writingIssues = WritingReviewService.review(markdown: updated)
        writingReviewStatus = writingIssues.isEmpty ? "No writing issues found." : nil
    }

    // MARK: Photo management

    /// Removes a photo from the strip and its ref from the body.
    /// The staging file is kept until Reset (deferred deletion).
    private func removePhoto(_ photo: ExportedPhoto) {
        pendingDeletion.append(photo.localURL)
        pendingPost.photos.removeAll { $0.id == photo.id }
        pendingPost.markdownBody = MarkdownGenerator.removePhotoRef(
            photo: photo, from: pendingPost.markdownBody)
    }

    /// Deduplicates `newPhotos` against current photos, appends them, and
    /// adds their refs to the markdown body.
    private func addPhotos(_ newPhotos: [ExportedPhoto]) {
        let existing = Set(pendingPost.photos.map(\.filename))
        let fresh = newPhotos.filter { !existing.contains($0.filename) }
        guard !fresh.isEmpty else { return }
        pendingPost.photos.append(contentsOf: fresh)
        for photo in fresh {
            pendingPost.markdownBody = MarkdownGenerator.appendPhotoRef(
                photo: photo, to: pendingPost.markdownBody)
        }
    }

    /// Opens an NSOpenPanel so the user can pick photos/videos to add.
    private func pickAndAddPhotos() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .movie]
        // Capture settings on the main thread before going async
        let stagingDir = stagingDirectory
        let urlPrefix = settings.imageURLPrefix
        let imagesSubpath = settings.staticImagesSubpath
        panel.begin { response in
            guard response == .OK else { return }
            let urls = panel.urls
            guard !urls.isEmpty else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                try? FileManager.default.createDirectory(
                    at: stagingDir, withIntermediateDirectories: true)
                var photos: [ExportedPhoto] = []
                let videoExts: Set<String> = ["mp4", "mov", "webm"]
                for url in urls {
                    let exifDate = PhotoExporter.readDate(from: url)
                    let filename = PhotoExporter.exportedFilename(
                        originalName: url.lastPathComponent, date: exifDate)
                    let dest = stagingDir.appendingPathComponent(filename)
                    try? FileManager.default.removeItem(at: dest)
                    try? FileManager.default.copyItem(at: url, to: dest)
                    let resolvedPrefix = AppSettings.resolveSubpath(urlPrefix, for: exifDate)
                    let slash = resolvedPrefix.hasSuffix("/") ? resolvedPrefix : resolvedPrefix + "/"
                    let sub = AppSettings.resolveSubpath(imagesSubpath, for: exifDate)
                    let mdPath: String
                    if sub.isEmpty {
                        mdPath = "\(slash)\(filename)"
                    } else {
                        let subSlash = sub.hasSuffix("/") ? sub : sub + "/"
                        mdPath = "\(slash)\(subSlash)\(filename)"
                    }
                    let isVideo = videoExts.contains(url.pathExtension.lowercased())
                    photos.append(ExportedPhoto(
                        filename: filename, markdownPath: mdPath,
                        localURL: dest, exifDate: exifDate, isVideo: isVideo))
                }
                DispatchQueue.main.async { addPhotos(photos) }
            }
        }
    }

    private func previewInBrowser() {
        guard save(runGitAutomation: false) else { return }
        guard let profile = settings.activeProfile,
              !profile.blogRoot.isEmpty,
              let url = HugoServerManager.previewURL(
                  profile: profile,
                  date: pendingPost.postDate,
                  slug: pendingPost.slug
              ) else {
            publishError = "Cannot compute preview URL — check Blog Root and Content Path in Settings."
            return
        }
        let wasRunning = hugoServer.isRunning
        if !wasRunning {
            hugoServer.start(blogRoot: profile.blogRoot, hugoPath: profile.hugoPath)
        }
        hugoServer.openInBrowser(url: url, serverWasAlreadyRunning: wasRunning)
    }

    private func reloadBodyFromDisk(url: URL) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return }
        var fmEnd = -1
        for (i, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces) == "---" { fmEnd = i + 1; break }
        }
        guard fmEnd > 0 else { return }
        let body = fmEnd + 1 < lines.count ? lines[(fmEnd + 1)...].joined(separator: "\n") : ""
        if body != pendingPost.markdownBody {
            pendingPost.markdownBody = body
        }
    }

    private func prepopulateMarkdown() {
        guard !pendingPost.photos.isEmpty, pendingPost.markdownBody.isEmpty else { return }
        pendingPost.markdownBody = MarkdownGenerator.initialBody(photos: pendingPost.photos)
    }

    @discardableResult
    private func save(runGitAutomation: Bool = true) -> Bool {
        publishError = nil
        gitStatus = nil
        guard settings.isConfigured else {
            publishError = "Configure paths in Settings first."
            return false
        }
        guard !pendingPost.title.isEmpty else {
            titleIsInvalid = true
            return false
        }
        guard !pendingPost.slug.isEmpty else {
            publishError = "Filename (slug) cannot be empty."
            return false
        }
        let date = pendingPost.postDate
        do {
            // When re-editing, images are already in place — skip copying.
            let imageURLs = isReEditing
                ? []
                : (try PhotoExporter.copyPendingToStatic(photos: pendingPost.photos, settings: settings))
            let fullContent = MarkdownGenerator.frontmatter(
                title: pendingPost.title,
                date: date,
                categories: pendingPost.categories,
                tags: pendingPost.tags,
                series: pendingPost.series,
                customFields: settings.activeProfile?.customFrontmatterFields ?? []
            ) + "\n" + pendingPost.markdownBody
            let mdURL: URL
            if let existingURL = pendingPost.existingFileURL {
                fileWatcher.ignoreNextChange()
                try MarkdownGenerator.write(content: fullContent, to: existingURL)
                mdURL = existingURL
            } else {
                mdURL = try MarkdownGenerator.write(
                    content: fullContent,
                    filename: fullFilename,
                    date: date,
                    settings: settings
                )
            }
            pendingPost.lastPublished = PublishedRecord(
                markdownURL: mdURL,
                imageURLs: imageURLs,
                title: pendingPost.title
            )
            // Staging files and editor state are preserved until Reset

            if runGitAutomation, settings.activeProfile?.autoGitCommit == true {
                let blogRoot = settings.activeProfile?.blogRoot ?? ""
                let template = settings.activeProfile?.gitCommitTemplate ?? "Add post: {{title}}"
                let message = template.replacingOccurrences(of: "{{title}}", with: pendingPost.title)
                Task.detached(priority: .utility) {
                    let result = GitRunner.commitAndPush(blogRoot: blogRoot, commitMessage: message)
                    await MainActor.run {
                        switch result {
                        case .success:
                            gitStatus = "Committed & pushed"
                            gitSuccess = true
                        case .failure(let err):
                            gitStatus = err.localizedDescription
                            gitSuccess = false
                        }
                    }
                }
            }
            return true
        } catch {
            publishError = error.localizedDescription
            return false
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
        // Delete files deferred from remove actions
        for url in pendingDeletion { try? fm.removeItem(at: url) }
        pendingDeletion = []
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

// MARK: - Preview Block Model

struct PostPreviewBlock: Identifiable {
    let id: Int
    enum Kind { case text(String); case image(ExportedPhoto); case video(ExportedPhoto) }
    let kind: Kind

    nonisolated static func mediaCaption(for photo: ExportedPhoto) -> String {
        photo.filename
    }
}
