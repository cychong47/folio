# Photolog Feature History

This document tracks implemented product capabilities at a feature level.
`HISTORY.md` remains the release changelog parsed by CI, while this file records
completed roadmap items and the user workflow they enable.

## Implemented

### Photo Date Quick Picks

Status: implemented for the Photos date range picker.

Related releases:

- v1.21.55 — the Photos date range picker shows Recent Posts and Recent Photo
  Browses side by side; choosing either one fills the current From/To fields
  while leaving final loading behind the existing confirmation button.

User value:

- Users can start photo curation from memory of a recent post instead of
  remembering the exact capture date.
- Users can restore previously browsed Photos-library ranges without retyping
  dates or timezone options.

Implementation notes:

- `PhotoBrowseHistoryStore` persists the five most recent confirmed photo
  browse ranges in shared user defaults.
- `DateRangePickerView` receives recent posts from the current blog content
  index and recent browse ranges from the history store.
- Quick Pick rows only fill the picker controls; they do not immediately scan
  Photos until the user confirms.

Primary verification:

- `PhotoBrowseHistoryStoreTests` covers newest-first ordering, deduplication,
  history limits, and manual no-location timezone offsets.

### Revise Writing Sidebar

Status: implemented as a local deterministic writing-review MVP.

Related releases:

- v1.21.52 — the post editor gained a Revise sidebar that checks markdown for
  common Korean spelling corrections, repeated adjacent words, long sentences,
  and image references with empty alt text.
- v1.21.53 — Preview and Revise now share a tabbed right panel, keeping the
  editor as a two-pane layout during both writing and review.
- v1.21.54 — Revise findings are grouped by category, users can ignore
  individual suggestions for the current review, and the local Korean correction
  list covers additional conservative typo patterns.

User value:

- Korean posts can be reviewed before saving without sending draft content to a
  network service.
- Suggestions stay passive: the editor never rewrites the post unless the user
  clicks Apply on a specific replacement.
- Suggestions can be hidden one by one while reviewing a draft, reducing noise
  without changing the saved markdown.
- Existing posts opened from Browse Posts get the same review surface as new
  photo-backed posts.

Implementation notes:

- `WritingReviewService` is UI-independent and returns stable ranges,
  categories, excerpts, and optional replacements.
- `PostEditorRightPanelMode` controls whether the right side of
  `PostEditorView` shows Preview or Revise.
- Missing alt text and long-sentence findings are advisory; Korean spelling and
  repeated-word findings can be applied directly.
- `WritingReviewService.groupedIssues(_:)` keeps category ordering stable for
  the Revise UI and tests.

Primary verification:

- `WritingReviewServiceTests` covers Korean corrections, missing alt text,
  repeated adjacent words, category grouping, and range-based replacement.

### Persistent Drafts

Status: implemented across the main editor and editor-window flows.

Related releases:

- v1.21.44 — editor windows persist unsaved draft metadata and selected photo
  references, so drafts created from curation or Browse Posts can be resumed
  after restart or update.
- v1.21.51 — drag-and-drop and New Post drafts autosave through the same draft
  store, so unfinished photo selections and markdown from the main editor can be
  resumed after restart or update.

User value:

- Photo selections no longer need to be reconstructed after app restart or app
  update.
- Long photo-backed posts can be edited over multiple sessions.
- Saved posts clear stale autosaved draft state without closing the editor
  unexpectedly.

Implementation notes:

- `PostDraftStore` stores snapshots of `PendingPost` in Application Support.
- Editor-window drafts are updated from `PostEditorWindowView`.
- Main-window drag-and-drop and New Post drafts are updated from `ContentView`.
- Draft snapshots include title, slug, date override, markdown body, taxonomy,
  series, existing post URL, and staged photo references.

Primary verification:

- `PostDraftStoreTests` covers persisted draft reload, removal, curation draft
  independence, existing post drafts, pending-post snapshot creation, and draft
  replacement.
- Full suite passed for v1.21.51 with 59 tests.
