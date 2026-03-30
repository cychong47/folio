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
        case awaitingInstall
        case error(String)
    }

    @Published var state: State = .idle

    let currentVersion: String
    private static let releasesURL = URL(string: "https://api.github.com/repos/cychong47/blogger/releases/latest")!

    init() {
        currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    func checkForUpdates() {
        Task { await _check() }
    }

    func downloadAndInstall(downloadURL: String) {
        Task { await _download(from: downloadURL) }
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
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("Blogger-update.zip")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)
            NSWorkspace.shared.open(dest)
            state = .awaitingInstall
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
