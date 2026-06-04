# Plan: Git Commit & Push on Save (issue #22)

## Goal

After a post is saved successfully, optionally run `git add -A && git commit -m "<message>" && git push` in the blog's root directory. This is a per-profile toggle with an optional commit message template.

---

## Acceptance criteria recap

- Per-profile toggle: "Auto git commit on Save"
- Optional commit message template (e.g. `Add post: {{title}}`)
- Runs git in the blog root directory (`BlogProfile.blogRoot`)
- Shows success/error inline in the editor footer
- Works with any remote (GitHub, GitLab, Gitea, self-hosted)

---

## What already exists (relevant touchpoints)

| File | What it provides |
|---|---|
| `folio/Models/BlogProfile.swift:9-27` | Per-profile struct; already has `blogRoot: String` |
| `folio/Models/AppSettings.swift:62-68` | `updateActiveProfile()` for mutating the active profile |
| `folio/Views/SettingsView.swift:233-632` | `ProfileDetailPanel` — where new UI rows go |
| `folio/Views/PostEditorView.swift:533-573` | `save()` — where git call is triggered after success |
| `folio/Views/PostEditorView.swift:469-506` | Footer status bar driven by `publishError: String?` |
| `folio/Views/Theme.swift` | Design tokens (colours, spacing) |

---

## Changes required

### 1. `folio/Models/BlogProfile.swift` — add two fields

```swift
var autoGitCommit: Bool = false
var gitCommitTemplate: String = "Add post: {{title}}"
```

Add them with default values so existing JSON-decoded profiles (which lack these keys) decode without errors — `BlogProfile` uses `Codable` with default values, so this is safe.

**Nothing else in the model layer needs to change.**

---

### 2. New file: `folio/Services/GitRunner.swift`

A small, focused service that shells out to `git`. It must:

- Accept a `workingDirectory: URL` (from `blogRoot`) and a `commitMessage: String`
- Run three commands sequentially, stopping on first failure:
  1. `git add -A`
  2. `git commit -m "<message>"` — if the exit code signals "nothing to commit" (exit 1 with that stderr phrase), treat as a no-op success
  3. `git push`
- Return a `Result<Void, GitRunner.GitError>` where `GitError` carries the stderr output for display
- Run synchronously on whichever thread the caller is on (the caller dispatches to a background thread; see §4)

Key implementation notes:
- Use `Process` + `Pipe` (Foundation), not `NSTask` wrappers — no extra dependencies
- Do not inherit the app's environment blindly; set `PATH` to include `/usr/bin:/usr/local/bin:/opt/homebrew/bin` so `git` is found even when the app is sandboxed or launched from Finder
- Timeout: send `SIGTERM` after 30 s to avoid hanging the UI forever

**Error cases to surface clearly:**
| Condition | Message shown in footer |
|---|---|
| `blogRoot` is empty | "Git: blog root not configured" |
| `git` not found in PATH | "Git: git not found — install Xcode Command Line Tools" |
| `git add -A` fails | "git add failed: \<stderr\>" |
| Nothing to commit | *(silent — treat as success)* |
| `git commit` fails | "git commit failed: \<stderr\>" |
| `git push` fails (no remote, auth, etc.) | "git push failed: \<stderr\>" |

---

### 3. `folio/Views/SettingsView.swift` — new rows in `ProfileDetailPanel`

Add a new section after the existing "Hugo Preview" section (around line 557), before the closing of the form:

```
Section("Git") {
    Toggle("Auto git commit on Save", isOn: $profile.autoGitCommit)

    if profile.autoGitCommit {
        TextField("Commit message template", text: $profile.gitCommitTemplate)
            .font(Theme.monoFont)   // consistent with other template fields
        Text("Use {{title}} for the post title.")
            .font(.caption)
            .foregroundColor(Theme.secondaryLabel)
    }
}
```

The section only shows the template field when the toggle is on — keeps the UI minimal when the feature is off.

---

### 4. `folio/Views/PostEditorView.swift` — call GitRunner after save succeeds

#### 4a. New state

```swift
@State private var gitStatus: String? = nil   // nil = idle, non-nil = message to show
@State private var gitSuccess: Bool = false    // true = green, false = red
```

#### 4b. In `save()`, after the existing success path (after `publishError = nil` and the successful write at line ~563)

```swift
if settings.activeProfile?.autoGitCommit == true {
    let template = settings.activeProfile?.gitCommitTemplate ?? "Add post: {{title}}"
    let message = template.replacingOccurrences(of: "{{title}}", with: title)
    let root = settings.activeProfile?.blogRoot ?? ""
    
    Task.detached(priority: .utility) {
        let result = GitRunner.run(in: URL(fileURLWithPath: root),
                                   commitMessage: message)
        await MainActor.run {
            switch result {
            case .success:
                gitStatus = "Committed & pushed"
                gitSuccess = true
            case .failure(let err):
                gitStatus = err.localizedDescription
                gitSuccess = false
            }
        }
    }
}
```

#### 4c. Footer display

The existing footer shows `publishError` in red. Extend it to also show `gitStatus` below the existing error/status row:

```swift
if let status = gitStatus {
    HStack(spacing: 4) {
        Image(systemName: gitSuccess ? "checkmark.circle" : "exclamationmark.triangle")
            .foregroundColor(gitSuccess ? Theme.accentGreen : Theme.errorRed)
        Text(status)
            .font(Theme.captionFont)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
```

Clear `gitStatus = nil` at the start of each `save()` call (same place `publishError = nil` is cleared).

---

## File change summary

| File | Nature of change |
|---|---|
| `folio/Models/BlogProfile.swift` | +2 fields (`autoGitCommit`, `gitCommitTemplate`) |
| `folio/Services/GitRunner.swift` | New file (~80 lines) |
| `folio/Views/SettingsView.swift` | +1 Git section in ProfileDetailPanel |
| `folio/Views/PostEditorView.swift` | +2 state vars, git call after save, footer row |
| `project.yml` | Bump version (1.10.2 → 1.11.0) |
| `HISTORY.md` | Add bullet under v1.11 |
| `README.md` | Add feature bullet |
| `docs/features.md` | Add under "Publishing" or new "Version Control" group |

---

## Out of scope

- SSH key management or git credential setup — the user's system git config handles auth
- Staging specific files — `git add -A` in the blog root is intentional (matches normal Hugo workflow)
- Pull-before-push — out of scope for v1; add as a follow-up if requested
- Showing a diff — too complex for an editor footer; out of scope

---

## Open questions before coding

1. **Sandboxing**: The app uses an App Group but is it also sandboxed (`com.apple.security.app-sandbox` entitlement)? If so, `Process` (shelling out) is blocked. Check `folio/folio.entitlements` — if sandboxed, we'd need to use `NSAppleScript` or an XPC helper, which is a significantly larger change. **Resolve this first.**

2. **"Nothing to commit" detection**: `git commit` exits 1 with the message "nothing to commit, working tree clean". The implementation should parse stderr/stdout for this phrase to avoid surfacing it as an error.

3. **Footer layout**: The current footer is an `HStack` with fixed elements. If both `publishError` and `gitStatus` are set simultaneously, the footer may overflow. Consider a `VStack` or replacing `publishError` with a unified status model.
