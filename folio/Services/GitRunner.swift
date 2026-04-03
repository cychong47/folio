import Foundation

/// Runs `git add -A && git commit && git push` in the blog root directory.
/// All methods are synchronous — call from a background thread.
enum GitRunner {

    enum GitError: LocalizedError {
        case emptyBlogRoot
        case commandFailed(step: String, output: String)

        var errorDescription: String? {
            switch self {
            case .emptyBlogRoot:
                return "Git: blog root not configured"
            case .commandFailed(let step, let output):
                let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
                return "git \(step) failed: \(trimmed.isEmpty ? "(no output)" : trimmed)"
            }
        }
    }

    /// Stages all changes, commits with `commitMessage`, then pushes.
    /// Returns `.success` if everything went through, or if there was nothing to commit.
    static func commitAndPush(blogRoot: String, commitMessage: String) -> Result<Void, GitError> {
        guard !blogRoot.isEmpty else { return .failure(.emptyBlogRoot) }
        let dir = URL(fileURLWithPath: blogRoot)

        if let err = run("add", args: ["-A"], in: dir) { return .failure(err) }

        let commitResult = runRaw("commit", args: ["-m", commitMessage], in: dir)
        if case .failure(let f) = commitResult {
            // "nothing to commit" is not an error — treat as success and stop here
            if f.output.contains("nothing to commit") { return .success(()) }
            return .failure(.commandFailed(step: "commit", output: f.output))
        }

        if let err = run("push", args: [], in: dir) { return .failure(err) }

        return .success(())
    }

    // MARK: - Private helpers

    private struct RunFailure: Error { let output: String }

    private static func run(_ subcommand: String, args: [String], in dir: URL) -> GitError? {
        if case .failure(let f) = runRaw(subcommand, args: args, in: dir) {
            return .commandFailed(step: subcommand, output: f.output)
        }
        return nil
    }

    private static func runRaw(_ subcommand: String, args: [String], in dir: URL) -> Result<Void, RunFailure> {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = [subcommand] + args
        p.currentDirectoryURL = dir

        // Merge stdout+stderr so we capture all relevant output in one pipe
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe

        var env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? ""
        if !path.contains("/usr/bin") {
            env["PATH"] = "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin:\(path)"
        }
        p.environment = env

        do { try p.run() } catch {
            return .failure(RunFailure(output: error.localizedDescription))
        }

        // Wait up to 30 s; terminate if it hangs
        let sema = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in sema.signal() }
        if sema.wait(timeout: .now() + 30) == .timedOut {
            p.terminate()
            return .failure(RunFailure(output: "timed out after 30 s"))
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return p.terminationStatus == 0 ? .success(()) : .failure(RunFailure(output: output))
    }
}
