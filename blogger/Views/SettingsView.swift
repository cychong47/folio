import SwiftUI

// Codable snapshot used for export / import
private struct SettingsExport: Codable {
    var profiles: [BlogProfile]
    var selectedProfileID: UUID?
    var appTheme: String
}

// MARK: - mergeCategories (file-level helper)

private func mergeCategories(_ existing: [String], _ new: [String]) -> [String] {
    var seen = Set<String>()
    var result: [String] = []
    for cat in existing + new {
        if seen.insert(cat.lowercased()).inserted {
            result.append(cat)
        }
    }
    return result.sorted()
}

// MARK: - Root Settings (tab container)

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 740, height: 560)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var editingProfileID: UUID? = nil
    @State private var profileToDelete: BlogProfile? = nil
    @State private var importError: String? = nil
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                ProfileSidebarPanel(
                    editingProfileID: $editingProfileID,
                    profileToDelete: $profileToDelete
                )
                ProfileDetailPanel(
                    editingProfileID: $editingProfileID,
                    isScanning: $isScanning
                )
            }

            Divider()

            HStack(spacing: 8) {
                Button("Export…") { exportSettings() }
                Button("Import…") { importSettings() }
                if let err = importError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onAppear {
            editingProfileID = settings.selectedProfileID ?? settings.profiles.first?.id
        }
        .confirmationDialog(
            "Delete \"\(profileToDelete?.name ?? "")\"?",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let id = profileToDelete?.id {
                    settings.profiles.removeAll { $0.id == id }
                    if settings.selectedProfileID == id {
                        settings.selectedProfileID = settings.profiles.first?.id
                    }
                    editingProfileID = settings.profiles.first?.id
                }
                profileToDelete = nil
            }
            Button("Cancel", role: .cancel) { profileToDelete = nil }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func exportSettings() {
        let snapshot = SettingsExport(
            profiles: settings.profiles,
            selectedProfileID: settings.selectedProfileID,
            appTheme: settings.appTheme
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "blogger-settings.json"
        panel.prompt = "Export"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    private func importSettings() {
        importError = nil
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let s = try JSONDecoder().decode(SettingsExport.self, from: data)
            settings.profiles = s.profiles
            settings.selectedProfileID = s.selectedProfileID
            settings.appTheme = s.appTheme
            editingProfileID = settings.selectedProfileID
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profile Sidebar Panel

private struct ProfileSidebarPanel: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var editingProfileID: UUID?
    @Binding var profileToDelete: BlogProfile?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(settings.profiles) { profile in
                        let isActive = profile.id == (settings.selectedProfileID ?? settings.profiles.first?.id)
                        let isEditing = profile.id == editingProfileID
                        ProfileSidebarRow(
                            profile: profile,
                            isActive: isActive,
                            isEditing: isEditing,
                            onSelect: {
                                editingProfileID = profile.id
                                settings.selectedProfileID = profile.id
                            },
                            onDelete: { profileToDelete = profile }
                        )
                        if profile.id != settings.profiles.last?.id {
                            Divider()
                        }
                    }
                }
            }

            Divider()

            Button {
                let newProfile = BlogProfile(name: "")
                settings.profiles.append(newProfile)
                editingProfileID = newProfile.id
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Blog")
                    Spacer()
                }
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)
    }
}

// MARK: - Profile Sidebar Row

private struct ProfileSidebarRow: View {
    let profile: BlogProfile
    let isActive: Bool
    let isEditing: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name.isEmpty ? "Unnamed" : profile.name)
                    .font(.callout)
                    .lineLimit(1)
                if !profile.blogRoot.isEmpty {
                    Text(profile.blogRoot)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isEditing ? Color.accentColor.opacity(0.12) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .contextMenu {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}

// MARK: - Profile Detail Panel

private struct ProfileDetailPanel: View {
    @EnvironmentObject var settings: AppSettings
    @Binding var editingProfileID: UUID?
    @Binding var isScanning: Bool

    @State private var draft = BlogProfile(name: "")

    var body: some View {
        Group {
            if editingProfileID == nil || settings.profiles.isEmpty {
                VStack {
                    Spacer()
                    Text(settings.profiles.isEmpty
                         ? "Click \"+ Add Blog\" to create your first blog profile."
                         : "Select a blog from the list.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Name
                        TextField("Blog name", text: $draft.name)
                            .font(.headline)
                            .padding(.bottom, 16)

                        // Blog Root
                        PathRow(label: "Blog Root",
                                placeholder: "/Users/you/blog",
                                path: $draft.blogRoot,
                                onChoose: pickBlogRoot)

                        Divider().padding(.vertical, 10)

                        HStack(alignment: .top, spacing: 0) {
                            Text("Hugo Paths")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.bottom, 6)

                        PathRow(label: "Content",
                                placeholder: "/Users/you/blog/content/posts",
                                path: $draft.contentPath)
                        PathRow(label: "Images",
                                placeholder: "/Users/you/blog/static/images",
                                path: $draft.staticImagesPath)

                        if !draft.blogRoot.isEmpty {
                            Text("Auto-filled from Blog Root. Edit to override.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 6)
                        }

                        Divider().padding(.vertical, 10)

                        HStack(alignment: .top, spacing: 0) {
                            Text("Subpath Templates")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("Tokens: YYYY · MM · DD")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                        .padding(.bottom, 6)

                        HStack(alignment: .top, spacing: 20) {
                            SubpathField(label: "Content Posts",
                                         placeholder: "e.g. YYYY/MM",
                                         value: $draft.contentSubpath,
                                         previewSuffix: "/slug.md")
                            SubpathField(label: "Static Images",
                                         placeholder: "e.g. YYYY/MM  (leave empty for flat)",
                                         value: $draft.staticImagesSubpath,
                                         previewSuffix: "/")
                        }
                        .padding(.bottom, 10)

                        Divider().padding(.vertical, 10)

                        HStack {
                            SectionLabel("Categories")
                            Spacer()
                            Button(isScanning ? "Scanning…" : "Scan Posts") {
                                scanCategories()
                            }
                            .disabled(draft.contentPath.isEmpty || isScanning)
                        }
                        .padding(.bottom, 4)

                        if draft.knownCategories.isEmpty {
                            Text(draft.contentPath.isEmpty
                                 ? "Set up content path above, then scan."
                                 : "No categories yet. Click \"Scan Posts\" to collect from existing posts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        } else {
                            let categoriesBinding = Binding<[String]>(
                                get: { draft.knownCategories },
                                set: { draft.knownCategories = $0 }
                            )
                            CategoryTagsEditor(categories: categoriesBinding)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadDraft() }
        .onChange(of: editingProfileID) { _ in loadDraft() }
        .onChange(of: draft) { newDraft in
            guard let idx = settings.profiles.firstIndex(where: { $0.id == newDraft.id }),
                  settings.profiles[idx] != newDraft else { return }
            settings.profiles[idx] = newDraft
        }
    }

    private func loadDraft() {
        guard let id = editingProfileID,
              let profile = settings.profiles.first(where: { $0.id == id }) else { return }
        draft = profile
    }

    private func pickBlogRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let fm = FileManager.default
        let oldDerivedContent = draft.blogRoot + "/content/posts"
        let oldDerivedImages  = draft.blogRoot + "/static/images"
        draft.blogRoot = url.path
        if draft.contentPath.isEmpty || draft.contentPath == oldDerivedContent {
            let postPath  = url.path + "/content/post"
            let postsPath = url.path + "/content/posts"
            draft.contentPath = fm.fileExists(atPath: postPath) ? postPath : postsPath
        }
        if draft.staticImagesPath.isEmpty || draft.staticImagesPath == oldDerivedImages {
            draft.staticImagesPath = url.path + "/static/images"
        }
    }

    private func scanCategories() {
        guard let profileID = editingProfileID,
              !draft.contentPath.isEmpty else { return }
        let contentPath = draft.contentPath
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let found = CategoryScanner.scan(contentPath: contentPath)
            DispatchQueue.main.async {
                // Only update draft — onChange(of: draft) writes back to settings
                guard editingProfileID == profileID else { isScanning = false; return }
                draft.knownCategories = mergeCategories(draft.knownCategories, found)
                isScanning = false
            }
        }
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel("Theme")
            HStack {
                Text("Appearance")
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
                Picker("", selection: $settings.appTheme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(minHeight: 120)
    }
}

// MARK: - Shared sub-components

private struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.headline)
            .padding(.bottom, 8)
    }
}

private struct PathRow: View {
    let label: String
    let placeholder: String
    @Binding var path: String
    var onChoose: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .trailing)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $path)
                .truncationMode(.middle)
            Button("Choose…") { onChoose != nil ? onChoose!() : pickFolder() }
        }
        .padding(.bottom, 6)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }
}

private struct SubpathField: View {
    let label: String
    let placeholder: String
    @Binding var value: String
    let previewSuffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $value)
            if !value.isEmpty {
                let resolved = AppSettings.resolveSubpath(value, for: Date())
                Text("→ …/\(resolved)\(previewSuffix)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct CategoryTagsEditor: View {
    @Binding var categories: [String]
    @State private var newText = ""
    @State private var showInput = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(categories, id: \.self) { cat in
                    HStack(spacing: 3) {
                        Text(cat).font(.caption)
                        Button {
                            categories.removeAll { $0 == cat }
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(4)
                }
            }
            HStack(spacing: 6) {
                if showInput {
                    TextField("New category", text: $newText)
                        .frame(width: 160)
                        .onSubmit { commitNew() }
                    Button("Add") { commitNew() }
                    Button("Cancel") { showInput = false; newText = "" }
                        .foregroundStyle(.secondary)
                } else {
                    Button("+ Add category") { showInput = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                        .font(.caption)
                }
            }
        }
    }

    private func commitNew() {
        let quoteChars = CharacterSet(charactersIn: "\"\'\u{201C}\u{201D}\u{2018}\u{2019}")
        let trimmed = newText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: quoteChars)
        let alreadyExists = categories.contains { $0.lowercased() == trimmed.lowercased() }
        if !trimmed.isEmpty && !alreadyExists {
            categories = (categories + [trimmed]).sorted()
        }
        newText = ""
        showInput = false
    }
}
