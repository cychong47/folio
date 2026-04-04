# Plan: Taxonomy Manager (issue #21)

## Goal

Add a dedicated view that aggregates all categories, tags, and series across the entire Hugo site with post counts, and lets users rename or merge them in bulk across files.

---

## Acceptance criteria recap

- List all taxonomy terms with post counts
- Rename a term: updates frontmatter in every affected file
- Merge two terms: replaces one with the other across all files
- Available per blog profile in Settings

---

## What already exists (relevant touchpoints)

| File | What it provides |
|---|---|
| `folio/Services/CategoryScanner.swift` | `parseFrontmatterCategories/Tags/Series` — reused directly to avoid duplication |
| `folio/Models/BlogProfile.swift` | `knownCategories`, `knownTags`, `knownSeries: [String]` — kept in sync after rename/merge |
| `folio/Models/AppSettings.swift:62-68` | `updateActiveProfile()` — used to update known-term lists after mutations |
| `folio/Views/SettingsView.swift:233-657` | `ProfileDetailPanel` — entry point; "Manage…" button added after Series section |
| `folio/Views/Theme.swift` | `Theme.chipBg`, `Theme.accent` — used in term row badges |

---

## Architecture

Three layers:

1. **Service** (`TaxonomyManager`) — stateless enum; scan for counts, rename, merge, in-place frontmatter rewriter
2. **Model** (`TaxonomyTerm`, `TaxonomyKind`) — value types; no persistence, always derived live
3. **View** (`TaxonomyManagerView`) — sheet presented from `ProfileDetailPanel`

---

## Changes required

### 1. New file: `folio/Services/TaxonomyManager.swift`

Provides three static operations plus a private frontmatter rewriter.

**`TaxonomyKind` enum**
```swift
enum TaxonomyKind: String, CaseIterable, Identifiable {
    case categories, tags, series
}
```

**`TaxonomyTerm` struct**
```swift
struct TaxonomyTerm: Identifiable, Hashable {
    let name: String
    let postCount: Int
}
```

**`TaxonomyManager.scan(contentPath:) -> [TaxonomyKind: [TaxonomyTerm]]`**
- Walks all `.md` files; calls `CategoryScanner.parseFrontmatterXxx` static methods
- Builds `[String: Int]` frequency map per kind
- Returns sorted `TaxonomyTerm` arrays

**`TaxonomyManager.rename(from:to:kind:in:) throws -> Int`**
- Enumerates all `.md` files; calls `rewriteTerm()` on each
- Writes back atomically with `String.write(to:atomically:encoding:)` only when content changed
- Returns count of modified files

**`TaxonomyManager.merge(source:into:kind:in:) throws -> Int`**
- Thin wrapper: calls `rename(from: source, to: target, ...)` — merge IS rename once deduplication is handled in the rewriter

**`rewriteTerm(in:replacing:with:kind:) -> String?`**
Handles all three YAML formats the scanner recognises:

| Format | Example | Strategy |
|---|---|---|
| Single-line flow | `categories: [Foo, Bar]` | Split on `,`, swap, deduplicate, re-join |
| Multi-line block | `categories:\n  - Foo\n  - Bar` | Swap matching `- term` line, remove duplicate lines |
| Scalar (series only) | `series: Name` | Direct string replacement on the value segment |

Returns `nil` if the term is not present (avoids unnecessary file writes).
Operates only within the frontmatter block (between `---` delimiters).

---

### 2. New file: `folio/Views/TaxonomyManagerView.swift`

A sheet (`frame(width: 520, height: 420)`) with:

- **Header**: title, Refresh button, progress spinner while loading
- **Segmented picker**: Categories / Tags / Series tab selector (`TaxonomyKind`)
- **List**: one `TaxonomyTermRow` per term; shows name + post-count capsule badge
- **Status bar**: last operation result message (appears after rename/merge)

**`TaxonomyTermRow`** (private sub-view):
- Right-click context menu: "Rename…" and "Merge into…"
- Rename flow: inline sheet with `TextField` pre-filled with current name
- Merge flow: inline sheet with `Picker` (radio group) listing all other terms of the same kind
- Both operations dispatch work to `DispatchQueue.global(qos: .userInitiated)`, post back on `DispatchQueue.main`
- On success: calls `settings.updateActiveProfile` to sync `knownXxx` arrays, then triggers a re-scan

**State vars:**
```swift
@State private var terms: [TaxonomyKind: [TaxonomyTerm]] = [:]
@State private var isLoading = false
@State private var statusMessage: String? = nil
@State private var selectedKind: TaxonomyKind = .categories
```

No `async/await` — consistent with all other services in the codebase.

---

### 3. `folio/Views/SettingsView.swift` — new "Taxonomy" row in `ProfileDetailPanel`

Added after the existing Series section, before Image Export:

```swift
@State private var showTaxonomyManager = false

// In body:
HStack {
    SectionLabel("Taxonomy")
    Spacer()
    Button("Manage…") { showTaxonomyManager = true }
        .disabled(draft.contentPath.isEmpty)
}
Text("Rename or merge categories, tags, and series across all posts.")
    .font(.caption).foregroundStyle(.secondary)

// On the outer Group:
.sheet(isPresented: $showTaxonomyManager) {
    TaxonomyManagerView(contentPath: draft.contentPath)
        .environmentObject(settings)
}
```

The sheet receives `draft.contentPath` directly so it stays bound to the profile being edited, not `settings.activeProfile` (which could differ if the user is editing a non-active profile).

---

## Key design decisions

**Why a sheet rather than a new Settings tab?**
Taxonomy is profile-scoped. A "Manage…" button inside the profile detail panel is more discoverable and keeps the Settings tab bar from growing.

**Why not re-generate frontmatter from scratch during rename?**
`MarkdownGenerator.frontmatter()` does not preserve unknown keys (`weight`, `showToc`, etc.). In-place targeted substitution within only the matching line is the only safe approach for posts authored outside Folio.

**Why is merge implemented as rename?**
After substituting `source → target`, the rewriter deduplicates within each file. A post that had both terms ends up with one occurrence of `target`. No separate merge logic needed.

**Why pass `contentPath` to the sheet rather than reading `settings.activeProfile`?**
Avoids a subtle footgun: the user could be editing profile B while profile A is active. The sheet must use the draft's `contentPath`.

---

## File change summary

| File | Nature of change |
|---|---|
| `folio/Services/TaxonomyManager.swift` | New file — scan, rename, merge, in-place rewriter |
| `folio/Views/TaxonomyManagerView.swift` | New file — sheet with term list, rename/merge flows |
| `folio/Views/SettingsView.swift` | +1 state var, +Taxonomy section, +sheet modifier |
| `project.yml` | Bump version 1.12.1 → 1.13.0 |
| `HISTORY.md` | Add bullet under v1.13.0 |
| `README.md` | Add feature bullet |
| `docs/features.md` | Add under "Categories & Taxonomy" group |

---

## Out of scope

- Undo/undo history — file writes are atomic but not reversible from within the app; the user's git history is the recovery path
- Adding new terms from the manager — existing `CategoryTagsEditor` in Settings already handles this
- Sorting or filtering the term list — post count is shown; alphabetical sort is sufficient for typical sites
- Taxonomy types beyond categories/tags/series — Hugo supports custom taxonomies but Folio's frontmatter only writes these three
