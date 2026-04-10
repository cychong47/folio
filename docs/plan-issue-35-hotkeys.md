# Plan: Keyboard Shortcuts / Hot-Keys (issue #35)

## Goal

Add keyboard shortcuts for four actions, plus a "Check for Updates" menu bar item that shows an inline popup result:

1. **New Post** (text/no photo) — `Cmd+N`
2. **Browse Posts** — `Cmd+B`
3. **Save** — `Cmd+S`
4. **Publish** — `Cmd+Shift+U`
5. **Check for Updates** — menu bar item only; shows a small popup with status and a Download button if an update is available

Reset gets no shortcut. Actions 1 and 2 are only active in the main welcome/editor window.

---

## Shortcut choices

| Action | Shortcut | Rationale |
|---|---|---|
| New Post | `Cmd+N` | macOS standard for "new document" |
| Browse Posts | `Cmd+B` | Mnemonic: **B**rowse |
| Save | `Cmd+S` | macOS standard; replaces non-standard `Cmd+Shift+Return` |
| Publish | `Cmd+Shift+U` | p**U**blish; `Cmd+P` is reserved by system Print dialog |
| Check Update | *(menu item only)* | In `CommandMenu("Folio")` in the menu bar |

---

## What already exists (relevant touchpoints)

| File | What it provides |
|---|---|
| `folio/FolioApp.swift:4-67` | `@main` app; `@StateObject` for `settings` and `pendingPost`; `.commands` block |
| `folio/ContentView.swift` | Top-level routing; hosts `.sheet` modifiers |
| `folio/Views/WelcomeView.swift:37-42` | "New Post" and "Browse Posts" buttons |
| `folio/Views/PostEditorView.swift:531-549` | Footer buttons including Save (`Cmd+Shift+Return`) and Publish |
| `folio/Services/UpdateChecker.swift` | `@MainActor ObservableObject`; `state` enum with `.idle / .checking / .upToDate / .available / .downloading / .awaitingInstall / .error`; `checkForUpdates()` and `downloadAndInstall()` methods |
| `folio/Views/SettingsView.swift:762-870` | `UpdatesTab` owns `@StateObject private var checker = UpdateChecker()` — this will be replaced with an injected instance |

---

## Changes required

### 1. `folio/Views/WelcomeView.swift` — New Post & Browse Posts

```swift
Button("New Post") { startTextPost() }
    .keyboardShortcut("n", modifiers: .command)

Button("Browse Posts") { onBrowse?() }
    .keyboardShortcut("b", modifiers: .command)
```

Buttons are already absent when editing or browsing — SwiftUI disables the shortcut automatically.

---

### 2. `folio/Views/PostEditorView.swift` — Save & Publish

**Save**: remove `.keyboardShortcut(.return, modifiers: [.command, .shift])`, replace with:

```swift
Button("Save") { save() }
    .keyboardShortcut("s", modifiers: .command)
```

**Publish**: add shortcut to the existing conditionally-disabled button:

```swift
Button("Publish") { publishToGitHub() }
    .keyboardShortcut("u", modifiers: [.command, .shift])
```

---

### 3. Lift `UpdateChecker` to app level

`UpdateChecker` currently lives as a private `@StateObject` inside `UpdatesTab` (SettingsView). To trigger it from the menu bar and show a popup in the main window, it needs to be owned at a higher level.

**`folio/FolioApp.swift`**: add `@StateObject private var updateChecker = UpdateChecker()` alongside the existing `settings` and `pendingPost` state objects, and inject it as an `@EnvironmentObject`:

```swift
@StateObject private var updateChecker = UpdateChecker()

// inside WindowGroup { ContentView() ... }
.environmentObject(updateChecker)
```

**`folio/Views/SettingsView.swift` / `UpdatesTab`**: replace `@StateObject private var checker = UpdateChecker()` with `@EnvironmentObject var checker: UpdateChecker`. Remove the `@StateObject` declaration — the instance is now shared.

---

### 4. `folio/FolioApp.swift` — Check for Updates menu bar item

Add a `CommandMenu("Folio")` that triggers the shared checker and opens the popup:

```swift
.commands {
    // existing CommandGroup for About...
    CommandMenu("Folio") {
        Button("Check for Updates…") {
            updateChecker.checkForUpdates()
            showUpdatePopup = true
        }
    }
}
```

Add `@State private var showUpdatePopup = false` to `FolioApp`, and attach a `.sheet` on `ContentView`:

```swift
.sheet(isPresented: $showUpdatePopup) {
    UpdatePopupView(checker: updateChecker)
}
```

---

### 5. New file: `folio/Views/UpdatePopupView.swift`

A small, focused sheet showing the update check result. It reuses the `UpdateChecker.State` enum already defined.

```
┌─────────────────────────────────┐
│  Check for Updates              │
│                                 │
│  [spinner] Checking…            │
│  — or —                         │
│  ✓  Folio is up to date.        │
│  — or —                         │
│  ↓  Version v1.16 is available  │
│     [Download & Install]        │
│  — or —                         │
│  ⚠  Update check failed         │
│     <error detail>              │
│                                 │
│                      [Close]    │
└─────────────────────────────────┘
```

States mirror `UpdateChecker.State`: `.checking` shows a spinner; `.upToDate` shows a checkmark; `.available` shows the version and a "Download & Install" button that calls `checker.downloadAndInstall()`; `.error` shows the message. The `.downloading` and `.awaitingInstall` states (post-click) are shown inline in the same popup.

Keep it narrow (~340 pt wide), non-resizable, with a single "Close" button at the bottom.

---

## File change summary

| File | Nature of change |
|---|---|
| `folio/Views/WelcomeView.swift` | Add `Cmd+N` / `Cmd+B` to New Post / Browse Posts buttons |
| `folio/Views/PostEditorView.swift` | Replace `Cmd+Shift+Return` → `Cmd+S` for Save; add `Cmd+Shift+U` for Publish |
| `folio/FolioApp.swift` | Add `@StateObject updateChecker`; inject as env object; add `CommandMenu("Folio")`; add `.sheet` for `UpdatePopupView` |
| `folio/Views/UpdatePopupView.swift` | New file — small update status popup |
| `folio/Views/SettingsView.swift` | Replace `@StateObject private var checker` → `@EnvironmentObject var checker` in `UpdatesTab` |
| `project.yml` | Bump version → 1.15.0 |
| `HISTORY.md` | Add bullet under v1.15 |
| `README.md` | Add keyboard shortcuts reference |
| `docs/features.md` | Add under "Editor" or new "Keyboard Shortcuts" group |

---

## Out of scope

- Reset keyboard shortcut (dropped by design)
- Customisable shortcuts — macOS System Settings > Keyboard > App Shortcuts covers menu items
- Preview shortcut — not in issue #35
- Touch Bar support — deprecated
