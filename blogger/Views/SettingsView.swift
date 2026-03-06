import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

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

            HStack {
                Text("URL Prefix")
                    .frame(width: 110, alignment: .trailing)
                    .foregroundStyle(.secondary)
                TextField("/images", text: $settings.imageURLPrefix)
                    .frame(maxWidth: 200)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(24)
        .frame(width: 620, height: 370)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.return, modifiers: [.command])
            }
        }
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
