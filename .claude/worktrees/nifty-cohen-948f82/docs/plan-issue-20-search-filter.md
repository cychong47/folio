# Plan: Search and Filter Posts (Issue #20)

## Goal

Add a search bar and filter controls to `PostListView` so users can quickly find posts across a large site. Filters operate in-memory on the already-loaded `[PostSummary]` array — no new disk I/O needed.

## Acceptance Criteria (from issue)

1. Search field that filters by **title and body text**
2. Filter controls for **category, tag, series, and draft status**
3. **Date range picker** to narrow results by publish date

---

## Data Available

`PostSummary` already carries everything we need:
- `title: String`
- `bodyText: String`
- `categories: [String]`
- `tags: [String]`
- `series: String`
- `isDraft: Bool`
- `date: Date`

Known taxonomy values for dropdowns come from `AppSettings`:
- `knownCategories`, `knownTags`, `knownSeries`

---

## Architecture

### No new files needed

All changes are **contained to `PostListView.swift`**. No new service or model is required because:
- Posts are already fully loaded into `@State var posts: [PostSummary]`
- Filtering is a pure computed transform on that array
- Known taxonomy lists come from the existing `AppSettings` (passed as `@EnvironmentObject`)

### Filter state

Add `@State` properties to `PostListView`:

```swift
@State private var searchQuery: String = ""
@State private var filterCategory: String? = nil
@State private var filterTag: String? = nil
@State private var filterSeries: String? = nil
@State private var filterDraft: Bool? = nil        // nil = all, true = drafts only, false = published only
@State private var filterDateFrom: Date? = nil
@State private var filterDateTo: Date? = nil
@State private var showFilters: Bool = false
```

### Computed filtered list

```swift
private var filteredPosts: [PostSummary] {
    posts.filter { post in
        // Search: title or body
        let matchesSearch = searchQuery.isEmpty
            || post.title.localizedCaseInsensitiveContains(searchQuery)
            || post.bodyText.localizedCaseInsensitiveContains(searchQuery)

        // Category chip
        let matchesCategory = filterCategory == nil
            || post.categories.contains(filterCategory!)

        // Tag chip
        let matchesTag = filterTag == nil
            || post.tags.contains(filterTag!)

        // Series chip
        let matchesSeries = filterSeries == nil
            || post.series == filterSeries!

        // Draft toggle
        let matchesDraft = filterDraft == nil
            || post.isDraft == filterDraft!

        // Date range
        let matchesFrom = filterDateFrom == nil
            || post.date >= filterDateFrom!
        let matchesTo = filterDateTo == nil
            || post.date <= filterDateTo!

        return matchesSearch && matchesCategory && matchesTag
            && matchesSeries && matchesDraft && matchesFrom && matchesTo
    }
}
```

Replace the `posts` reference in the `List` with `filteredPosts`.

---

## UI Layout

```
┌─────────────────────────────────────────────┐
│ ← Back          Posts (12)        ↺  ⊞ Filter │  ← header bar (existing + filter toggle)
├─────────────────────────────────────────────┤
│ 🔍 Search titles and content…               │  ← search bar (always visible)
├─────────────────────────────────────────────┤  ← collapsible filter panel (showFilters)
│ Draft:  [All ▾]                             │
│ Category: [Any ▾]   Tag: [Any ▾]            │
│ Series:  [Any ▾]                            │
│ Date: [from picker] → [to picker]           │
│                              [Clear filters]│
├─────────────────────────────────────────────┤
│  Mar 15, 2025  My Post Title         Draft  │
│  …                                          │
└─────────────────────────────────────────────┘
```

### Header bar changes
- Add a filter toggle button (system image `line.3.horizontal.decrease.circle`) next to the refresh button
- Post count in the title reflects filtered count: `"Posts (\(filteredPosts.count))"`

### Search bar
- `TextField` using `Theme` styling (rounded rect, cream background)
- Debounce not needed — filtering is synchronous on already-loaded array

### Filter panel (`showFilters == true`)
- `Menu` (native macOS dropdown) for category, tag, series — populated from `AppSettings.knownCategories` etc.
- Draft filter: segmented `Picker` with options All / Drafts / Published
- Date range: two `DatePicker` controls (`.graphical` style or `.compact`) labeled "From" and "To"
- "Clear filters" button — resets all filter state and collapses the panel
- Wrap in `VStack` with `.padding()` and `Divider()` separator

### Active filter indicators
- When any filter is active, show small capsule chips in the header (below search bar) — one per active filter, each with an `×` to clear just that filter
- This mirrors the existing category chip style in `PostRowView`

---

## Implementation Steps

1. **Add `@EnvironmentObject var settings: AppSettings`** to `PostListView` (needed for taxonomy dropdowns)
2. **Add filter `@State` vars** as listed above
3. **Add `filteredPosts` computed property**
4. **Update the `List`** to iterate `filteredPosts` instead of `posts`
5. **Add `activeFilterCount` computed var** (for badge on filter button)
6. **Build `SearchBarView`** — inline `HStack` with magnifying glass icon + `TextField` + clear button
7. **Build `FilterPanelView`** — `VStack` with dropdowns, draft picker, date pickers, clear button
8. **Update header** — add filter toggle button, update title to show filtered count
9. **Compose in `PostListView.body`** — search bar + conditional filter panel above the `List`
10. **Update `HISTORY.md`, `README.md`, `docs/features.md`, bump version, run xcodegen, commit + push**

---

## Scope Boundaries

- **In scope:** In-memory filtering on loaded posts, all filter types from acceptance criteria
- **Out of scope:** Full-text indexing (Spotlight / SQLite), sorting controls, saved filter presets — these can be separate issues
- **Body text search note:** `bodyText` is already loaded by `PostIndexer`; no additional I/O is needed. Performance should be acceptable for typical blog sizes (< 1000 posts).

---

## Files to Change

| File | Change |
|------|--------|
| `folio/Views/PostListView.swift` | All UI + filter logic |
| `HISTORY.md` | Add bullet under current version |
| `README.md` | Add feature bullet |
| `docs/features.md` | Add under Browse & Manage category |
| `project.yml` | Bump `CFBundleShortVersionString` |
| `Folio.xcodeproj` | Regenerated by xcodegen |

No new files are needed.
