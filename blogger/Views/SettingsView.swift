import SwiftUI

// Codable snapshot used for export / import
private struct SettingsExport: Codable {
    var baseBlogPath: String
    var contentPath: String
    var staticImagesPath: String
    var imageURLPrefix: String
    var contentSubpath: String
    var staticImagesSubpath: String
    var knownCategories: [String]
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
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionLabel("Blog Root")

            PathRow(label: "Blog Root",
                    placeholder: "/Users/you/blog",
                    path: $settings.baseBlogPath,
                    onChoose: pickBlogRoot)

            Divider().padding(.vertical, 12)

            SectionLabel("Hugo Paths")

            PathRow(label: "Content",
                    placeholder: "/Users/you/blog/content/posts",
                    path: $settings.contentPath)
            PathRow(label: "Images",
                    placeholder: "/Users/you/blog/static/images",
                    path: $settings.staticImagesPath)

            if !settings.baseBlogPath.isEmpty {
                Text("Auto-filled from Blog Root. Edit to override.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }

            Divider().padding(.vertical, 16)

            HStack(alignment: .top, spacing: 0) {
                SectionLabel("Subpath Templates")
                Spacer()
                Text("Tokens: YYYY · MM · DD")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }

            HStack(alignment: .top, spacing: 20) {
                SubpathField(label: "Content Posts",
                             placeholder: "e.g. YYYY/MM",
                             value: $settings.contentSubpath,
                             previewSuffix: "/slug.md")
                SubpathField(label: "Static Images",
                             placeholder: "e.g. YYYY/MM  (leave empty for flat)",
                             value: $settings.staticImagesSubpath,
                             previewSuffix: "/")
            }
            .padding(.top, 6)

            Divider().padding(.vertical, 16)

            SectionLabel("Image URL")

            HStack(alignment: .center, spacing: 8) {
                Text("URL Prefix")
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("/images", text: $settings.imageURLPrefix)
                    .frame(maxWidth: 200)
                let resolvedSub = AppSettings.resolveSubpath(settings.staticImagesSubpath, for: Date())
                let rawPrefix = settings.imageURLPrefix.isEmpty ? "/images" : settings.imageURLPrefix
                let resolvedPrefix = AppSettings.resolveSubpath(rawPrefix, for: Date())
                let slash = resolvedPrefix.hasSuffix("/") ? resolvedPrefix : resolvedPrefix + "/"
                let preview = resolvedSub.isEmpty ? String(slash.dropLast()) : slash + resolvedSub
                Text("→ \(preview)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.top, 4)

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
    }

    private func exportSettings() {
        let snapshot = SettingsExport(
            baseBlogPath: settings.baseBlogPath,
            contentPath: settings.contentPath,
            staticImagesPath: settings.staticImagesPath,
            imageURLPrefix: settings.imageURLPrefix,
            contentSubpath: settings.contentSubpath,
            staticImagesSubpath: settings.staticImagesSubpath,
            knownCategories: settings.knownCategories
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
            settings.baseBlogPath      = s.baseBlogPath
            settings.contentPath        = s.contentPath
            settings.staticImagesPath  = s.staticImagesPath
            settings.imageURLPrefix    = s.imageURLPrefix
            settings.contentSubpath    = s.contentSubpath
            settings.staticImagesSubpath = s.staticImagesSubpath
            settings.knownCategories   = s.knownCategories
        } catch {
            importError = "Import failed: \(error.localizedDescription)"
        }
    }

    private func pickBlogRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let oldDerivedContent = settings.baseBlogPath + "/content/posts"
        let oldDerivedImages  = settings.baseBlogPath + "/static/images"
        settings.baseBlogPath = url.path
        if settings.contentPath.isEmpty || settings.contentPath == oldDerivedContent {
            settings.contentPath = url.path + "/content/posts"
        }
        if settings.staticImagesPath.isEmpty || settings.staticImagesPath == oldDerivedImages {
            settings.staticImagesPath = url.path + "/static/images"
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
                SectionLabel("Categories")
                Spacer()
                Button(isScanning ? "Scanning…" : "Scan Posts") {
                    guard !settings.contentPath.isEmpty else { return }
                    isScanning = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let found = CategoryScanner.scan(contentPath: settings.contentPath)
                        DispatchQueue.main.async {
                            settings.knownCategories = Array(
                                Set(settings.knownCategories + found)
                            ).sorted()
                            isScanning = false
                        }
                    }
                }
                .disabled(settings.contentPath.isEmpty || isScanning)
            }

            if settings.knownCategories.isEmpty {
                Text(settings.contentPath.isEmpty
                     ? "Set the Content Posts path in General, then scan."
                     : "No categories yet. Click \"Scan Posts\" to collect from existing posts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                CategoryTagsEditor(categories: $settings.knownCategories)
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
