import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var isScanning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Hugo Paths ────────────────────────────────────────────
            SectionLabel("Hugo Paths")

            PathRow(label: "Content Posts",
                    placeholder: "/Users/you/blog/content/posts",
                    path: $settings.contentPath)
            PathRow(label: "Static Images",
                    placeholder: "/Users/you/blog/static/images",
                    path: $settings.staticImagesPath)

            Divider().padding(.vertical, 16)

            // ── Subpath Templates (side-by-side) ──────────────────────
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

            // ── Image URL ─────────────────────────────────────────────
            SectionLabel("Image URL")

            HStack(alignment: .top) {
                Text("URL Prefix")
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
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
                }
            }
            .padding(.top, 4)

            Divider().padding(.vertical, 16)

            // ── Categories ────────────────────────────────────────────
            HStack {
                SectionLabel("Categories")
                Spacer()
                Button(isScanning ? "Scanning…" : "Scan Posts") {
                    guard !settings.contentPath.isEmpty else { return }
                    isScanning = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        let found = CategoryScanner.scan(contentPath: settings.contentPath)
                        DispatchQueue.main.async {
                            // Merge with any manually added categories
                            let merged = Array(Set(settings.knownCategories + found)).sorted()
                            settings.knownCategories = merged
                            isScanning = false
                        }
                    }
                }
                .disabled(settings.contentPath.isEmpty || isScanning)
            }

            if settings.knownCategories.isEmpty {
                Text(settings.contentPath.isEmpty
                     ? "Set the Content Posts path above, then scan."
                     : "No categories found. Click \"Scan Posts\" to collect from existing posts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                // Tag chips with remove buttons
                CategoryTagsEditor(categories: $settings.knownCategories)
                    .padding(.top, 4)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 620, height: 500)
    }
}

// MARK: - Sub-components

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

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 110, alignment: .trailing)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $path)
                .truncationMode(.middle)
            Button("Choose…") { pickFolder() }
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
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !categories.contains(trimmed) {
            categories = (categories + [trimmed]).sorted()
        }
        newText = ""
        showInput = false
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
