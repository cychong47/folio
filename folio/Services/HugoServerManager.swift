import Foundation
import AppKit

/// Manages a local `hugo server` process for previewing posts before publishing.
final class HugoServerManager: ObservableObject {
    @Published private(set) var isRunning = false

    private var process: Process?

    /// Starts `hugo server` in the given blog root directory.
    /// No-op if a server is already running.
    func start(blogRoot: String, hugoPath: String) {
        guard !isRunning else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        let executable = hugoPath.trimmingCharacters(in: .whitespaces)
        let cmd = (executable.isEmpty ? "hugo" : executable) + " server --disableFastRender"
        p.arguments = ["-c", cmd]
        p.currentDirectoryURL = URL(fileURLWithPath: blogRoot)
        // Suppress output so it doesn't appear in Console
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                self?.process = nil
            }
        }
        do {
            try p.run()
            process = p
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    /// Opens the post URL in the default browser.
    /// Delays 2 s when the server was just started to give Hugo time to build.
    func openInBrowser(url: URL, serverWasAlreadyRunning: Bool) {
        let delay: TimeInterval = serverWasAlreadyRunning ? 0 : 2.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Computes the Hugo local-server URL for a post.
    ///
    /// Hugo's section is the part of `contentPath` after the first path component
    /// under `blogRoot` (e.g. `.../blog/content/posts` → section `posts`).
    static func previewURL(profile: BlogProfile, date: Date, slug: String) -> URL? {
        let blogRoot = profile.blogRoot
        let contentPath = profile.contentPath
        guard !blogRoot.isEmpty, !contentPath.isEmpty, !slug.isEmpty else { return nil }

        let prefix = blogRoot.hasSuffix("/") ? blogRoot : blogRoot + "/"
        guard contentPath.hasPrefix(prefix) else { return nil }

        // relativeContent = "content/posts" (or similar)
        let relativeContent = String(contentPath.dropFirst(prefix.count))
        // Hugo section = everything after the first component ("content")
        let parts = relativeContent.split(separator: "/", maxSplits: 1)
        let hugoSection = parts.count >= 2 ? String(parts[1]) : ""

        let subpath = AppSettings.resolveSubpath(profile.contentSubpath, for: date)

        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let filename = "\(df.string(from: date))-\(slug)"

        let segments = ([hugoSection] + subpath.split(separator: "/").map(String.init) + [filename])
            .filter { !$0.isEmpty }
        let urlPath = "/" + segments.joined(separator: "/") + "/"
        return URL(string: "http://localhost:1313\(urlPath)")
    }
}
