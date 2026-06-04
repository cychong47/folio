# Plan: Hugo Page Bundle Support — Issue #19

## Goal
Add a per-profile "Use page bundles" toggle. When enabled:
- Post is saved as `content/posts/<slug>/index.md` (leaf bundle directory)
- Images are copied into that same directory (not `static/images/`)
- Markdown image refs use relative paths (`![](photo.jpg)`) instead of absolute (`![](/images/...)`)

---

## Files to Change

### 1. `folio/Models/BlogProfile.swift`
- Add `var usePageBundles: Bool` field (default `false`, stored in Codable struct → auto-persisted via UserDefaults JSON).
- No other model changes needed; `staticImagesPath` and `imageURLPrefix` continue to work unchanged in non-bundle mode.

### 2. `folio/Views/SettingsView.swift`
- In the Profile Detail Panel, add a Toggle **"Use page bundles"** in the Hugo/Paths section (near `contentPath`).
- When enabled, grey-out / hide the "Static Images Path" and "Image URL Prefix" fields with a note: *"Images are saved alongside index.md"*.

### 3. `folio/Services/MarkdownGenerator.swift`
- `write(content:filename:date:settings:)` — when `settings.usePageBundles`:
  - Destination becomes `contentPath/<subpath>/<slug>/index.md` (create directory `<slug>/`).
  - Return the `index.md` URL as before.
- No change needed to the re-edit path (`write(content:to:)`) because `existingFileURL` already points to the correct file.

### 4. `folio/Services/PhotoExporter.swift`
- `copyPendingToStatic(photos:settings:)` — when `settings.usePageBundles`:
  - Destination directory = `contentPath/<subpath>/<slug>/` (same dir as `index.md`).
  - The slug must be passed in (see §5 below).
  - Image filenames stay the same; no prefix needed.
- `markdownImagePath(filename:settings:slugDir:)` — add optional `slugDir` parameter:
  - When page bundles: return just `filename` (relative path).
  - Otherwise: return existing `imageURLPrefix/filename` logic.

### 5. `folio/Views/PostEditorView.swift`
- In `save()`, when `settings.usePageBundles`:
  - Pass `slug` down to `PhotoExporter.copyPendingToStatic` so it can build the correct bundle path.
  - Pass `slug` + `subpath` to `MarkdownGenerator.write` so it builds `<slug>/index.md`.
- Update `buildMarkdownPath` calls (or the inline markdown generation) to use relative filenames in bundle mode.

### 6. `folio/Views/DropTargetView.swift`
- `buildMarkdownPath(filename:date:prefix:subpath:)` — add a `usePageBundles` branch:
  - If true, return just the bare `filename` string.
  - Otherwise, existing behavior.
- This affects the **live preview** markdown references shown in the editor before saving.

---

## AppSettings forwarding (`folio/Models/AppSettings.swift`)
- Add computed `var usePageBundles: Bool` forwarding to the active profile (alongside existing `contentPath`, `staticImagesPath`, etc.).

---

## Edge Cases
- **Re-editing an existing page-bundle post**: `existingFileURL` already points to `<slug>/index.md`; image copy logic should target the parent directory of that file. No new slug logic needed for edits.
- **Git auto-commit**: The commit stages `contentPath/**` which includes the new bundle directory — no change required.
- **Static Images Path / Image URL Prefix fields**: These remain stored in the profile and continue to work in non-bundle mode. When bundle mode is on, they are simply unused.

---

## Version bump
- Bump `CFBundleShortVersionString` in `project.yml` (both occurrences).
- Run xcodegen.
- Update `HISTORY.md`, `README.md`, `docs/features.md`.

---

## Out of Scope
- Branch bundles (Hugo `_index.md`) — leaf bundles only.
- Migrating existing posts to bundle format.
- Any UI to convert between modes on existing posts.
