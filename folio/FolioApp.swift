import SwiftUI

@main
struct FolioApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var pendingPost = PendingPost()

    private var preferredScheme: ColorScheme? {
        switch settings.appTheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(pendingPost)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear { appDelegate.pendingPost = pendingPost }
                .preferredColorScheme(preferredScheme)
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .preferredColorScheme(preferredScheme)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Folio") {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationVersion: version,
                        .version: BuildInfo.commitHash
                    ])
                }
            }
        }
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var pendingPost: PendingPost?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == Constants.urlScheme {
            loadPendingPost()
        }
    }

    func loadPendingPost() {
        guard let post = pendingPost else { return }
        do {
            let photos = try SharedContainerService.loadExportedPhotos()
            guard !photos.isEmpty else { return }
            DispatchQueue.main.async {
                post.photos = photos
                let firstDate = photos.first?.exifDate ?? Date()
                if post.slug.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    post.slug = formatter.string(from: firstDate)
                }
                post.markdownBody = MarkdownGenerator.initialBody(photos: photos)
            }
        } catch {
            print("[Folio] Failed to load pending post: \(error)")
        }
    }
}
