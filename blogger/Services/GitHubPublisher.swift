import Foundation

enum GitHubPublisher {

    struct GitHubError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Commits one or more files to a GitHub repo via the REST API and updates the branch ref.
    static func commit(
        files: [(relativePath: String, data: Data)],
        message: String,
        token: String,
        apiBase: String,    // e.g. "https://api.github.com/repos/owner/repo"
        ownerRepo: String,  // "owner/repo" — used in error messages only
        branch: String
    ) async throws {
        let base = URL(string: apiBase)!

        func apiRequest(_ path: String, method: String = "GET", body: [String: Any]? = nil) async throws -> [String: Any] {
            var req = URLRequest(url: base.appendingPathComponent(path))
            req.httpMethod = method
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
            if let body {
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                    ?? "HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                throw GitHubError(message: msg)
            }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }

        // 1. Get current HEAD SHA
        let refData: [String: Any]
        do {
            refData = try await apiRequest("git/ref/heads/\(branch)")
        } catch let e as GitHubError {
            throw GitHubError(message: "Step 1 (get branch '\(branch)'): \(e.message)\n\nCheck: repo '\(ownerRepo)' is correct, branch '\(branch)' exists, and token has repo read/write scope.")
        }
        guard let headSHA = (refData["object"] as? [String: Any])?["sha"] as? String else {
            throw GitHubError(message: "Could not read HEAD SHA for branch '\(branch)'")
        }

        // 2. Get base tree SHA from the commit
        let commitData: [String: Any]
        do {
            commitData = try await apiRequest("git/commits/\(headSHA)")
        } catch let e as GitHubError {
            throw GitHubError(message: "Step 2 (get commit): \(e.message)")
        }
        guard let treeSHA = (commitData["tree"] as? [String: Any])?["sha"] as? String else {
            throw GitHubError(message: "Could not read tree SHA")
        }

        // 3. Create a blob for each file
        var treeItems: [[String: String]] = []
        for file in files {
            let blobData: [String: Any]
            do {
                blobData = try await apiRequest("git/blobs", method: "POST", body: [
                    "content": file.data.base64EncodedString(),
                    "encoding": "base64"
                ])
            } catch let e as GitHubError {
                throw GitHubError(message: "Step 3 (upload '\(file.relativePath)'): \(e.message)")
            }
            guard let blobSHA = blobData["sha"] as? String else {
                throw GitHubError(message: "Could not create blob for \(file.relativePath)")
            }
            treeItems.append(["path": file.relativePath, "mode": "100644", "type": "blob", "sha": blobSHA])
        }

        // 4. Create a new tree on top of the base tree
        let newTreeData: [String: Any]
        do {
            newTreeData = try await apiRequest("git/trees", method: "POST", body: [
                "base_tree": treeSHA,
                "tree": treeItems
            ])
        } catch let e as GitHubError {
            throw GitHubError(message: "Step 4 (create tree): \(e.message)")
        }
        guard let newTreeSHA = newTreeData["sha"] as? String else {
            throw GitHubError(message: "Could not create tree")
        }

        // 5. Create the commit
        let newCommitData: [String: Any]
        do {
            newCommitData = try await apiRequest("git/commits", method: "POST", body: [
                "message": message,
                "tree": newTreeSHA,
                "parents": [headSHA]
            ])
        } catch let e as GitHubError {
            throw GitHubError(message: "Step 5 (create commit): \(e.message)")
        }
        guard let newCommitSHA = newCommitData["sha"] as? String else {
            throw GitHubError(message: "Could not create commit")
        }

        // 6. Update the branch ref
        do {
            _ = try await apiRequest("git/refs/heads/\(branch)", method: "PATCH", body: [
                "sha": newCommitSHA,
                "force": false
            ])
        } catch let e as GitHubError {
            throw GitHubError(message: "Step 6 (update ref): \(e.message)")
        }
    }

    // MARK: - Auto-detect from .git/config

    struct RepoInfo {
        let repo: String    // "owner/name"
        let branch: String
    }

    /// Reads the GitHub remote URL and current branch from the blog root's .git directory.
    static func detectRepoInfo(blogRoot: String) -> RepoInfo? {
        // Parse remote URL from .git/config
        let configURL = URL(fileURLWithPath: blogRoot + "/.git/config")
        guard let config = try? String(contentsOf: configURL, encoding: .utf8) else { return nil }

        var repo: String? = nil
        var inOrigin = false
        for line in config.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "[remote \"origin\"]" { inOrigin = true; continue }
            if trimmed.hasPrefix("[") { inOrigin = false; continue }
            if inOrigin && trimmed.hasPrefix("url") {
                let value = trimmed.components(separatedBy: "=").dropFirst()
                    .joined(separator: "=").trimmingCharacters(in: .whitespaces)
                // HTTPS: https://github.com/owner/repo.git
                if value.hasPrefix("https://github.com/") {
                    repo = value
                        .replacingOccurrences(of: "https://github.com/", with: "")
                        .replacingOccurrences(of: ".git", with: "")
                }
                // SSH: git@github.com:owner/repo.git
                else if value.hasPrefix("git@github.com:") {
                    repo = value
                        .replacingOccurrences(of: "git@github.com:", with: "")
                        .replacingOccurrences(of: ".git", with: "")
                }
            }
        }
        guard let repo else { return nil }

        // Parse branch from .git/HEAD
        let headURL = URL(fileURLWithPath: blogRoot + "/.git/HEAD")
        var branch = "main"
        if let head = try? String(contentsOf: headURL, encoding: .utf8) {
            let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("ref: refs/heads/") {
                branch = String(trimmed.dropFirst("ref: refs/heads/".count))
            }
        }

        return RepoInfo(repo: repo, branch: branch)
    }
}
