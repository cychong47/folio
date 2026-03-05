import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Hugo Paths") {
                PathField(label: "Content Posts Path", path: $settings.contentPath,
                          prompt: "e.g. /Users/you/blog/content/posts")
                PathField(label: "Static Images Path", path: $settings.staticImagesPath,
                          prompt: "e.g. /Users/you/blog/static/images")
            }

            Section("Image URL") {
                LabeledContent("URL Prefix") {
                    TextField("/images", text: $settings.imageURLPrefix)
                        .frame(maxWidth: 200)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(minWidth: 500, minHeight: 280)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    NSApp.keyWindow?.close()
                }
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
    }
}

private struct PathField: View {
    let label: String
    @Binding var path: String
    let prompt: String

    var body: some View {
        LabeledContent(label) {
            HStack {
                TextField(prompt, text: $path)
                    .truncationMode(.middle)
                Button("Choose…") { pickFolder() }
            }
        }
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
