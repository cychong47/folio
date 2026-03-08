import SwiftUI

// Codable snapshot used for export / import
private struct SettingsExport: Codable {
    var profiles: [BlogProfile]
    var selectedProfileID: UUID?
    var appTheme: String
}

// MARK: - Root Settings (tab container)

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            CategoriesTab()
                .tabItem { Label("Categories", systemImage: "tag") }

            AppearanceTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
        }
        .frame(width: 540)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var editingProfile: BlogProfile?
    @State private var profileToDelete: BlogProfile?
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack {
                SectionLabel("Blog Profiles")
                Spacer()
                Button {
                    editingProfile = BlogProfile(name: "")
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .font(.callout)
            }

            if settings.profiles.isEmpty {
                Text("No blog profiles. Click + Add Profile to create one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(settings.profiles) { profile in
                        let isActive = profile.id == (settings.selectedProfileID ?? settings.profiles.first?.id)
                        ProfileRow(
                            profile: profile,
                            isActive: isActive,
                            onSelect: { settings.selectedProfileID = profile.id },
                            onEdit:   { editingProfile = profile },
                            onDelete: { profileToDelete = profile }
                        )
                        if profile.id != settings.profiles.last?.id {
                            Divider().padding(.leading, 40)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .padding(.top, 4)
            }

            Divider().padding(.vertical, 16)

            HStack(spacing: 8) {
                Button("Export…") { exportSettings() }
                Button("Import…") { importSettings() }
                if let err = importError {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .padding(24)
        .sheet(item: $editingProfile) { profile in
            ProfileEditorSheet(profile: profile) { saved in
                if let idx = settings.profiles.firstIndex(where: { $0.id == saved.id }) {
                    settings.profiles[idx] = saved
                } else {
                    settings.profiles.append(saved)
                    settings.selectedProfileID = saved.id
                }
                editingProfile = nil
            } onCancel: {
                editingProfile = nil
            }
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
            settings.profiles        = s.profiles
            settings.selectedProfileID = s.selectedProfileID
            settings.appTheme        = s.appTheme
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profile row

private struct ProfileRow: View {
    let profile: BlogProfile
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
                .font(.system(size: 16))
                .onTapGesture { onSelect() }

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? "Unnamed" : profile.name)
                    .fontWeight(.medium)
                if !profile.blogRoot.isEmpty {
                    Text(profile.blogRoot)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }

            Spacer()

            Button("Edit") { onEdit() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .font(.callout)

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - Profile editor sheet

private struct ProfileEditorSheet: View {
    @State private var draft: BlogProfile
    let onSave: (BlogProfile) -> Void
    let onCancel: () -> Void

    init(profile: BlogProfile, onSave: @escaping (BlogProfile) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: profile)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var isNewProfile: Bool { draft.name.isEmpty && draft.blogRoot.isEmpty && draft.contentPath.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Text(isNewProfile ? "New Profile" : "Edit Profile")
                .font(.headline)
                .padding(.bottom, 16)

            // Name
            HStack {
                Text("Name")
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("My Blog", text: $draft.name)
            }
            .padding(.bottom, 10)

            // Blog Root
            PathRow(label: "Blog Root",
                    placeholder: "/Users/you/blog",
                    path: $draft.blogRoot,
                    onChoose: pickBlogRoot)

            Divider().padding(.vertical, 10)

            Text("Hugo Paths")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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

            Spacer()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                Button("Save") { onSave(draft) }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.name.isEmpty)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(width: 500, height: 430)
    }

    private func pickBlogRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let oldDerivedContent = draft.blogRoot + "/content/posts"
        let oldDerivedImages  = draft.blogRoot + "/static/images"
        draft.blogRoot = url.path
        if draft.contentPath.isEmpty || draft.contentPath == oldDerivedContent {
            draft.contentPath = url.path + "/content/posts"
        }
        if draft.staticImagesPath.isEmpty || draft.staticImagesPath == oldDerivedImages {
            draft.staticImagesPath = url.path + "/static/images"
        }
    }
}

// MARK: - Categories Tab

private struct CategoriesTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var isScanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel("Categories")
                    if let name = settings.activeProfile?.name, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, -4)
                    }
                }
                Spacer()
                Button(isScanning ? "Scanning…" : "Scan Posts") {
                    guard !settings.contentPath.isEmpty else { return }
                    isScanning = true
                    let contentPath = settings.contentPath
                    DispatchQueue.global(qos: .userInitiated).async {
                        let found = CategoryScanner.scan(contentPath: contentPath)
                        DispatchQueue.main.async {
                            let existing = settings.knownCategories
                            settings.updateActiveProfile {
                                $0.knownCategories = Array(Set(existing + found)).sorted()
                            }
                            isScanning = false
                        }
                    }
                }
                .disabled(settings.contentPath.isEmpty || isScanning)
            }

            if settings.knownCategories.isEmpty {
                Text(settings.contentPath.isEmpty
                     ? "Set up a blog profile in General, then scan."
                     : "No categories yet. Click \"Scan Posts\" to collect from existing posts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                let categoriesBinding = Binding<[String]>(
                    get: { settings.activeProfile?.knownCategories ?? [] },
                    set: { newVal in settings.updateActiveProfile { $0.knownCategories = newVal } }
                )
                CategoryTagsEditor(categories: categoriesBinding)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .frame(minHeight: 200)
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
        if !trimmed.isEmpty && !categories.contains(trimmed) {
            categories = (categories + [trimmed]).sorted()
        }
        newText = ""
        showInput = false
    }
}
