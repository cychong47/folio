import Foundation
import AppKit

@MainActor
final class UpdateChecker: ObservableObject {

    enum State {
        case idle
        case checking
        case upToDate
        case available(tagName: String, downloadURL: String)
        case downloading
        case readyToInstall(newAppURL: URL)
        case error(String)
    }

    @Published var state: State = .idle

    let currentVersion: String
    private static let releasesURL = URL(string: "https://api.github.com/repos/cychong47/folio/releases/latest")!

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkForUpdates() {
        // If an update is already extracted and ready, don't re-check — just re-show the popup.
        if case .readyToInstall = state { return }
        Task { await _check() }
    }

    func downloadAndInstall(downloadURL: String) {
        Task { await _download(from: downloadURL) }
    }

    /// Replaces the running app bundle with `newAppURL`, then relaunches.
    /// Runs in a detached background shell so it survives after NSApp.terminate().
    func installAndRelaunch(from newAppURL: URL) {
        let src = newAppURL.path
        let dst = Bundle.main.bundleURL.path
        // Copy to the parent dir so cp creates dst fresh (if dst already exists as a
        // directory, `cp -Rf src dst` nests src *inside* dst instead of replacing it).
        let dstParent = (dst as NSString).deletingLastPathComponent

        // Shell-escape single quotes in paths (POSIX ' → '\'' trick)
        func esc(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "'\\''") }

        // Remove old bundle first, then copy new one into the parent directory.
        // Subshell runs in background (&) → survives after Folio quits.
        let cmd = "( sleep 2 && rm -rf '\(esc(dst))' && cp -Rf '\(esc(src))' '\(esc(dstParent))' && open '\(esc(dst))' ) &"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", cmd]
        task.standardInput = FileHandle.nullDevice
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()

        // Wait briefly so the shell has time to fork the background subshell before we exit
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Private

    private func _check() async {
        state = .checking
        do {
            var req = URLRequest(url: Self.releasesURL)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                state = .error("Server returned HTTP \(code)")
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                state = .error("Could not parse release info from GitHub.")
                return
            }
            let assets = json["assets"] as? [[String: Any]] ?? []
            let zipAsset = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
            let downloadURL = zipAsset?["browser_download_url"] as? String ?? ""

            let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            if isNewer(remote: remoteVersion, current: currentVersion) {
                state = .available(tagName: tagName, downloadURL: downloadURL)
            } else {
                state = .upToDate
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func _download(from urlString: String) async {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            state = .error("No download asset found for this release.")
            return
        }
        state = .downloading
        do {
            let (zipURL, _) = try await URLSession.shared.download(from: url)

            // Extract on a background thread so the main thread stays free
            let extractDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("FolioUpdateExtract", isDirectory: true)

            let appURL: URL? = await Task.detached {
                try? FileManager.default.removeItem(at: extractDir)
                try? FileManager.default.createDirectory(at: extractDir,
                                                          withIntermediateDirectories: true)
                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                unzip.arguments = ["-o", zipURL.path, "-d", extractDir.path]
                unzip.standardOutput = FileHandle.nullDevice
                unzip.standardError = FileHandle.nullDevice
                guard (try? unzip.run()) != nil else { return nil }
                unzip.waitUntilExit()
                guard unzip.terminationStatus == 0 else { return nil }

                let contents = (try? FileManager.default.contentsOfDirectory(
                    at: extractDir, includingPropertiesForKeys: nil)) ?? []
                return contents.first { $0.pathExtension == "app" }
            }.value

            if let appURL {
                state = .readyToInstall(newAppURL: appURL)
            } else {
                // Extraction failed — fall back to manual: open the zip with Archive Utility
                NSWorkspace.shared.open(zipURL)
                state = .error("Could not extract the update automatically. The archive has been opened for manual install.")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func isNewer(remote: String, current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        let count = max(r.count, c.count)
        for i in 0..<count {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv > cv { return true }
            if rv < cv { return false }
        }
        return false
    }
}
