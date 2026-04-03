# Plan: Post List View — Browse & Re-edit Existing Posts (closes #15)

## Goal

Add a browse interface so the user can list all markdown files in `contentPath`, pick one, and open it in `PostEditorView` for re-editing (title, body, frontmatter, images).

---

## High-Level Approach

Keep the existing two-state model (`WelcomeView` / `PostEditorView`) and add a third state: `PostListView`. Switch between states via two buttons in `WelcomeView` ("New Post" / "Browse Posts") and a "← Back" button from the list. When a post is selected from the list, parse the file, populate `PendingPost`, and show `PostEditorView`.

No new persistence layer is needed — the list is always derived from the filesystem at browse time.

---

## New Files

| File | Purpose |
|------|---------|
| `folio/Models/PostSummary.swift` | Lightweight struct for list rows (parsed from .md frontmatter) |
| `folio/Services/PostIndexer.swift` | Scans contentPath, parses frontmatter → `[PostSummary]` |
| `folio/Views/PostListView.swift` | SwiftUI list + toolbar |

---

## Step-by-Step Implementation

### Step 1 — PostSummary model (`folio/Models/PostSummary.swift`)

```swift
struct PostSummary: Identifiable {
    let id: UUID = UUID()
    let fileURL: URL           // absolute path to .md file
    let title: String
    let date: Date
    let slug: String           // derived from filename
    let categories: [String]
    let tags: [String]
    let series: String
    let isDraft: Bool
    let bodyText: String       // full body after frontmatter (for re-loading)
    let rawFrontmatter: String // full YAML block (for fields we don't model)
}
```

No `Codable` needed — always reparsed from disk.

---

### Step 2 — PostIndexer service (`folio/Services/PostIndexer.swift`)

```swift
enum PostIndexer {
    static func scan(contentPath: String) -> [PostSummary]
}
```

Implementation:
1. `FileManager.default.enumerator(at:)` recursively under `contentPath`, collecting `*.md` files.
2. For each file, read contents and split on the second `---` delimiter to get frontmatter and body.
3. Reuse parsing helpers already in `CategoryScanner`:
   - `parseFrontmatterCategories(from:)` → categories
   - `parseFrontmatterTags(from:)` → tags
   - `parseFrontmatterSeries(from:)` → series
4. Add simple regex/string parsing for `title:`, `date:`, `draft:` (not in CategoryScanner yet).
5. Sort result by `date` descending.
6. Return `[PostSummary]`.

Run on a background thread (DispatchQueue.global) and publish result on main.

---

### Step 3 — PostListView (`folio/Views/PostListView.swift`)

Layout: full-window `List` with three columns per row, matching app's warm-cream theme from `Theme.swift`.

**Row content:**
- Date (formatted `MMM d, yyyy`) — secondary, left
- Title — primary, bold
- Category chips (capsule style, reuse pattern from `PostEditorView`)
- "Draft" badge if `isDraft == true`

**Toolbar / header:**
- Leading: "← Back" button → `onBack()` callback → returns to `WelcomeView`
- Trailing: Refresh button → re-scans contentPath

**Empty state:** If `contentPath` not configured → show "Configure a blog profile in Settings". If configured but no posts found → "No posts found in \(contentPath)".

**Selection:** `.onTapGesture` or `List(selection:)` → call `onSelect(PostSummary)` callback.

---

### Step 4 — PostLoader (method on PostEditorView or free function)

When a `PostSummary` is selected, populate `PendingPost` from it:

```swift
func loadPost(_ summary: PostSummary, into pendingPost: PendingPost, settings: AppSettings)
```

Steps:
1. `pendingPost.title = summary.title`
2. `pendingPost.slug = summary.slug`
3. `pendingPost.dateOverride = summary.date`
4. `pendingPost.categories = summary.categories`
5. `pendingPost.tags = summary.tags`
6. `pendingPost.series = summary.series`
7. `pendingPost.markdownBody = summary.bodyText`
8. Parse image references from `bodyText` (regex `!\[.*?\]\((.*?)\)`) → resolve each against `staticImagesPath` → create `ExportedPhoto` with `localURL` pointing to existing file on disk. Set `pendingPost.photos`.
9. Store `summary.fileURL` on `PendingPost` as `existingFileURL: URL?` (new field) so `save()` overwrites the original file rather than creating a new one.
10. Clear `pendingPost.lastPublished`.

**Image resolution:** Convert markdown image path (e.g. `/images/2026-03-05-photo.jpg`) to absolute URL using `staticImagesPath`. If file doesn't exist on disk, skip it (image may have been moved).

---

### Step 5 — PendingPost changes (`folio/Models/PendingPost.swift`)

Add one field:

```swift
@Published var existingFileURL: URL? = nil  // non-nil when re-editing a saved post
```

Add to `reset()`:
```swift
existingFileURL = nil
```

Update `isEmpty` if needed: a post loaded from disk with no photos but with body text should not be considered empty (title + slug + existingFileURL present → not empty).

---

### Step 6 — MarkdownGenerator save path (`folio/Services/MarkdownGenerator.swift`)

In `write(pendingPost:settings:)`, if `pendingPost.existingFileURL != nil`, write to that URL directly instead of computing a new path from slug/date/subpath. This preserves the original filename on re-edit.

---

### Step 7 — ContentView navigation (`folio/ContentView.swift`)

Add a `browsing: Bool` state variable. Update the root `ZStack`:

```swift
if pendingPost.isEmpty && !browsing {
    WelcomeView(
        onNewPost: { /* set slug */ },
        onBrowse: { browsing = true }
    )
} else if browsing && pendingPost.isEmpty {
    PostListView(
        onBack: { browsing = false },
        onSelect: { summary in
            loadPost(summary, into: pendingPost, settings: settings)
            browsing = false
        }
    )
} else {
    PostEditorView()  // also handles re-edit (existingFileURL set)
}
```

---

### Step 8 — WelcomeView changes (`folio/Views/WelcomeView.swift`)

Add a "Browse Posts" button next to "New Post". Use secondary button style (outlined / lower visual weight). Wire to `onBrowse` callback.

---

### Step 9 — PostEditorView: re-edit UX (`folio/Views/PostEditorView.swift`)

When `pendingPost.existingFileURL != nil`:
- Change toolbar title to "Edit Post" (or show filename).
- Hide or repurpose the "Publish to GitHub" button (GitHub publishing a re-edited post is out of scope for this issue — disable it with a tooltip "Re-publishing to GitHub not yet supported").
- "Save" still works normally (writes to `existingFileURL`).
- Auto-git-commit still works if enabled.

---

## Out of Scope (for this issue)

- Re-publishing edited posts to GitHub (issue #15 does not require this).
- Search / filter within the list (can be added later).
- Inline preview of post body in the list.
- Detecting and re-linking images that have been renamed or moved.

---

## Files Changed Summary

| File | Change |
|------|--------|
| `folio/Models/PostSummary.swift` | **New** |
| `folio/Services/PostIndexer.swift` | **New** |
| `folio/Views/PostListView.swift` | **New** |
| `folio/Models/PendingPost.swift` | Add `existingFileURL`, update `reset()`, update `isEmpty` |
| `folio/Services/MarkdownGenerator.swift` | Use `existingFileURL` when set |
| `folio/ContentView.swift` | Add `browsing` state, third navigation branch |
| `folio/Views/WelcomeView.swift` | Add "Browse Posts" button, `onBrowse` callback |
| `folio/Views/PostEditorView.swift` | Re-edit title, disable GitHub publish button |
| `folio/FolioApp.swift` | Pass `loadPost` or lift closure — minor if needed |
| `project.yml` | Add new source files to target |
| `HISTORY.md` | Changelog entry |
| `README.md` | Features bullet |
| `docs/features.md` | Feature entry |

---

## Sequence Diagram

```
WelcomeView
  └── "Browse Posts" tap
        → ContentView sets browsing=true
        → PostListView appears
              → PostIndexer.scan(contentPath) [background thread]
              → List of PostSummary rows rendered
              └── Row tap → loadPost(summary, into: pendingPost)
                              → pendingPost populated
                              → ContentView: browsing=false, pendingPost non-empty
                              → PostEditorView appears (re-edit mode)
                                    └── "Save" → MarkdownGenerator writes to existingFileURL
```

---

## Risk & Notes

- **Large blogs**: `PostIndexer.scan` reads every `.md` file. On blogs with thousands of posts this could be slow. Mitigate by running async and showing a progress spinner; a cache is out of scope.
- **Subpath layouts**: Hugo blogs can nest posts arbitrarily. The recursive enumerator handles this; slug is derived from the filename only (`lastPathComponent` without extension, stripping the date prefix).
- **Existing file overwrite**: When saving a re-edited post, if the user changes the slug, a new filename would be generated. Since we use `existingFileURL`, we always overwrite the original — the slug field becomes cosmetic on re-edit. This is intentional and simpler.
- **Photo staging**: Re-edited posts reference images already on disk in `staticImagesPath`. `ExportedPhoto.localURL` will point directly to those files; `PhotoExporter.copyPendingToStatic` must skip files whose source and destination are the same path to avoid a no-op copy error.
