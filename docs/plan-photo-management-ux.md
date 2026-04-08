# Plan: Photo Management UX — Add / Remove Photos in Editor

## Goal

Allow users to add, remove, and (optionally) reorder photos **after** entering editor
mode — without discarding the post and starting over.

Current state: once the editor opens, photos can only be manipulated by hand-editing
the markdown body. There is no visual affordance and no remove button.

---

## Milestones

### M1 — Markdown sync helpers (`MarkdownGenerator.swift`)
*Prerequisite for all other milestones.*

Add four pure-string helpers (no file I/O). Matching logic is robust to standard
Markdown syntax (e.g. `![alt](<path> "title")`), not just blank alt-text. For videos,
`appendPhotoRef` emits the Hugo shortcode instead of image syntax.

| Helper | Signature | Behaviour |
|--------|-----------|-----------|
| `removePhotoRef` | `(photo: ExportedPhoto, from body: String) -> String` | Delete the line referencing `photo.markdownPath` (image or video shortcode). No-op if not found. |
| `appendPhotoRef` | `(photo: ExportedPhoto, to body: String) -> String` | Append the correct ref (image or video) after the last existing ref, or at end of body. |
| `reorderPhotoRefs` | `(orderedPhotos: [ExportedPhoto], in body: String) -> String` | Extract all ref lines, reorder them to match `orderedPhotos`, splice back. Non-ref lines are untouched. |
| `referencedPaths` | `(in body: String) -> Set<String>` | Return the set of all markdown paths referenced in `body` (used by M6). |

**Verification:**
- [ ] `removePhotoRef` with a path that exists → its line is gone from result
- [ ] `removePhotoRef` with a path that does not exist → body unchanged
- [ ] `removePhotoRef` handles `![alt text](<path> "title")` (non-blank alt, optional title)
- [ ] `removePhotoRef` handles video shortcodes `{{< video … src="path" … >}}`
- [ ] `appendPhotoRef` (image) inserts `![]()` after the last existing ref, not at very end when trailing text follows
- [ ] `appendPhotoRef` (video) inserts the Hugo `{{< video >}}` shortcode, not an image ref
- [ ] `reorderPhotoRefs` produces ref lines in the requested order; non-ref lines are untouched
- [ ] `referencedPaths` returns all paths for both image and video refs in the body

---

### M2 — Photo strip UI (`PhotoStripView.swift`, new file)

A horizontally-scrollable `ScrollView` showing one thumbnail per `ExportedPhoto`.
Each thumbnail (`PhotoStripCell`):

- Fixed size **80 × 80 pt**, `scaledToFill` + `.clipped()`, rounded corners, shadow consistent with `Theme`
- Video files show a play-badge overlay instead of the image
- Hover → show an **×** button (top-right corner) via `.onHover`
- `.contextMenu` with "Remove Photo" for right-click (keyboard-accessible on macOS 13;
  `.onKeyPress` for Delete requires macOS 14 and is out of scope here)
- `onRemove(ExportedPhoto)` closure for both hover × and context menu
- Greyed out (opacity 0.4) when `photo.markdownPath` is in `orphanedPaths`
- `.accessibilityLabel("Photo: <filename>")` / `"Video: <filename>"`
- `.accessibilityAction(named: "Remove") { onRemove(photo) }`

The strip also shows a `+` button (after all thumbnails) that calls `onAddPhoto`.

The strip renders an empty-state dashed drop-hint — *"Drop photos here to add more"*
with a `+` button — when `photos` is empty.

Layout sits **between** `headerSection` and `editorSection` in `PostEditorView`,
spanning the full width, with vertical padding of `8 pt`.

**Verification:**
- [ ] Strip appears in `PostEditorView` regardless of photo count
- [ ] Each photo renders a thumbnail at 80 × 80 (`scaledToFill`, clipped)
- [ ] Video files show the play-badge overlay
- [ ] Hovering a thumbnail reveals the × button; moving away hides it
- [ ] Right-clicking a thumbnail shows "Remove Photo" context menu item
- [ ] Empty-state label + `+` button shown when `photos` is empty
- [ ] `+` button shown at end of strip when photos are present
- [ ] Strip is horizontally scrollable when photos overflow the view width
- [ ] Orphaned photo thumbnails are rendered at 0.4 opacity
- [ ] VoiceOver reads each thumbnail with filename label
- [ ] VoiceOver "Remove" action triggers `onRemove`

---

### M3 — Remove photo action (`PostEditorView.swift`)

Wire the `onRemove` closure from M2 to a new `removePhoto(_ photo: ExportedPhoto)`
method. Use **deferred deletion** — the staging file is kept on disk until Reset or
successful Publish/Save-and-close — so that `Cmd+Z` in the text editor can restore
the image ref without breaking the file reference.

1. Append `photo.localURL` to a new `@State private var pendingDeletion: [URL] = []`
2. Remove `photo` from `pendingPost.photos`
3. Call `MarkdownGenerator.removePhotoRef(photo:from:)` and assign result back to `pendingPost.markdownBody`

Update `deleteStagingFiles()` to also delete all URLs in `pendingDeletion` (called by
Reset and Publish).

**Verification:**
- [ ] Clicking × removes the thumbnail from the strip immediately
- [ ] Right-click → "Remove Photo" has the same effect
- [ ] The corresponding ref line disappears from the markdown editor body
- [ ] The live preview panel no longer shows that photo
- [ ] Staging file is still on disk immediately after remove (deferred delete)
- [ ] Staging file is deleted after Reset (via `deleteStagingFiles`)
- [ ] Staging file is deleted after successful Publish (via `deleteStagingFiles`)
- [ ] Removing the last photo leaves the strip in empty-state; post stays open (not reset)

---

### M4 — Add photos while in editor mode

**a) Fix `handleDroppedPhotos` to append, not regenerate**

`ContentView.handleDroppedPhotos` currently calls `MarkdownGenerator.initialBody(photos:)` for
every drop, wiping any user edits. Fix: when `pendingPost.markdownBody` is non-empty
(i.e. the editor is already open), append refs for new photos only via
`MarkdownGenerator.appendPhotoRef(photo:to:)`.

**b) Global drop zone is already always active**

`DropZone` lives in the `ContentView` ZStack and is always present — drops in editor
mode already reach `handleDroppedPhotos`. No change needed to `DropTargetView` beyond
the fix in (a).

**c) `+` button opens `NSOpenPanel`**

`PostEditorView.pickAndAddPhotos()` opens an `NSOpenPanel` (called on `@MainActor`,
safe from any SwiftUI `Button` action). Selected files are staged and added via a new
shared `addPhotos(_ newPhotos: [ExportedPhoto])` helper that deduplicates and calls
`appendPhotoRef` for each new photo.

**Verification:**
- [ ] Dragging a photo from Photos.app onto the editor window adds it to the strip and
      appends its ref to the markdown body (existing body content is preserved)
- [ ] Dragging a photo from Finder onto the editor window works the same way
- [ ] Dragging a photo that is already in the post is a no-op (deduplication)
- [ ] The new thumbnail appears in the strip immediately after drop
- [ ] The new ref line appears in the markdown editor and preview
- [ ] Clicking `+` opens a file picker filtered to image/video types
- [ ] A photo selected via the file picker is treated identically to a dragged photo
      (staged, deduplicated, ref appended, thumbnail shown)

---

### M5 — Drag-to-reorder within the strip *(stretch goal)*

Make thumbnails draggable within `PhotoStripView` using SwiftUI's `.onDrag` / `.onDrop`
with a custom `UTType` for internal reordering. On reorder:

1. Reorder `pendingPost.photos`
2. Call `MarkdownGenerator.reorderPhotoRefs(orderedPhotos:in:)` and write back to
   `pendingPost.markdownBody`

**Verification:**
- [ ] Dragging a thumbnail to a new position reorders the strip visually
- [ ] The ref lines in the markdown body match the new order
- [ ] The live preview reflects the new order
- [ ] Reordering does not affect non-ref lines in the markdown body

---

### M6 — Markdown-to-strip sync (read-only, visual only)

When the user manually edits `markdownBody` in the text editor, the strip should reflect
the current reference state. **Important:** do NOT remove photos from `pendingPost.photos`
based on text edits — only the × button and Reset do that. Only visually grey them out.

In `PostEditorView.onChange(of: pendingPost.markdownBody)`, after the existing preview
debounce, also compute:

```swift
let referenced = MarkdownGenerator.referencedPaths(in: newValue)
orphanedPaths = Set(pendingPost.photos.map(\.markdownPath)).subtracting(referenced)
```

Pass `orphanedPaths` into `PhotoStripView`.

**Verification:**
- [ ] Manually deleting an image ref line from the text editor greys out the thumbnail
      in the strip (photo is NOT removed from the strip)
- [ ] Restoring the ref line (via `Cmd+Z` or re-typing) un-greys the thumbnail
- [ ] Manually reordering refs in the text editor does not crash or remove thumbnails

---

## Files to Change

| File | Nature of change |
|------|-----------------|
| `folio/Services/MarkdownGenerator.swift` | Add `removePhotoRef`, `appendPhotoRef`, `reorderPhotoRefs`, `referencedPaths` |
| `folio/Views/PhotoStripView.swift` | **New file** — thumbnail strip with hover-remove, `+` button, empty-state |
| `folio/Views/PostEditorView.swift` | Embed `PhotoStripView`; add `removePhoto()`, `pickAndAddPhotos()`, `addPhotos()`; `pendingDeletion`; `orphanedPaths`; update `deleteStagingFiles()` |
| `folio/ContentView.swift` | Fix `handleDroppedPhotos` to append instead of regenerate when body is non-empty |
| `project.yml` | Bump `CFBundleShortVersionString` (both occurrences) |
| `HISTORY.md` | Add bullet under current version |
| `README.md` | Update drag-and-drop usage section |
| `docs/features.md` | Add under "Editor" group |

---

## Out of Scope

- Editing photo metadata (EXIF date, filename) after staging
- Cropping or rotating images inside Folio
- Multi-select remove (single × per photo is sufficient for v1)
- Persisting strip order to disk between sessions (order is captured in `markdownBody`)
- Support for pasting photos from the clipboard (`Cmd+V`) in the editor (future item)
- Delete-key removal in `PhotoStripCell` (requires `.onKeyPress`, macOS 14+)
