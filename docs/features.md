---
layout: default
title: Features
description: Full feature list for Photolog — a native macOS app for creating Hugo blog posts from photos
---

# Features

[← Release Notes](index)

---

## Content Authoring

- **Welcome action launcher** — the start window presents Drag Photos, New Post, Browse Posts, and Curate Photos as large icon tiles with labels below each symbol
- **Compact welcome window** — the start window opens shorter around the large action tiles while editor, browse, and curation modes keep a roomier working minimum
- **Welcome window size restoration** — returning to or relaunching the welcome screen restores a compact size that still leaves room for the Photos access banner
- **Post list view** — "Browse Posts" opens a full list of every `.md` file in the content directory, sorted by date descending; each row shows title, date, series, categories, and a Draft badge; select any post to re-edit it in a separate editor window while the browse list stays open
- **Split-view post editor** — monospaced markdown editor on the left; the right panel switches between text + image Preview and Revise writing checks
- **Revise writing panel** — the post editor can run local writing checks for Korean spelling corrections, repeated words, long sentences, and missing image alt text, with suggested replacements applied only when selected
- **Preview filename captions** — the post editor preview shows each media filename below its rendered image or video placeholder for editing reference only; captions are not written into the markdown file
- **Autosaved post drafts** — separate editor-window drafts persist unsaved post metadata and selected photo references, then expose a Resume Draft action on the welcome screen after restart or update
- **Post save confirmation** — successful Save keeps the editor visible, shows a dismissible auto-hiding confirmation, and clears the saved editor draft only after the editor window closes
- **External editor live reload** — body text in the editor refreshes automatically when the post file is modified by an external editor (VSCode, Neovim, etc.); changes made by Photolog's own Save are excluded
- **Live text + image preview** — typed text and photos rendered in sequence so you can see how captions relate to photos before publishing
- **Hugo frontmatter auto-generation** — title, date (with time and timezone offset), categories, tags, and series written automatically at Save time
- **Custom frontmatter fields** — define extra key/value pairs per profile (e.g. `author`, `description`, `og_image`) appended to every post's frontmatter
- **Live slug** — filename slug auto-generated from the title and kept in sync as you type; independently editable
- **Title validation** — Save is blocked with a red-bordered title field when the title is empty
- **Editable post date** — date picker in the editor header; defaults to first photo's EXIF date or today; changing it renames staged photos and updates markdown references
- **Series field** — optional series picker below Tags; written as `series: [Name]` in frontmatter

---

## Photo Curation

- **Photo Curation Workspace** — open a vacation photo folder with `⌘K`; photos are auto-grouped into timed events using centroid-anchored spatio-temporal clustering (90-minute temporal gap, 500-metre movement from the event center, or 4-hour event span triggers a new event)
- **Capture-local date filtering** — Photos-library date ranges prefer original/base asset resources and match the capture-local day shown in curation, using separated EXIF offsets, subsecond EXIF fields, inline EXIF offsets, GPS-derived timezones from PhotoKit or original metadata, manual UTC offsets for no-GPS/no-timezone Photos when selected, camera-local EXIF time when GPS is absent, or Photos' own date when EXIF is missing so previous-day and next-day timezone offsets do not leak into the selected day
- **Curation metadata diagnostics** — the curation sidebar follows the selected event and shows the Photos resource, parsed EXIF timestamp, timezone, selected date range, computed capture day, and final filter decision used for that scan row, making Photos-library metadata mismatches visible without leaving the app
- **Camera model display** — curation thumbnails and detail views show parsed camera make/model immediately after each photo timestamp when metadata is available
- **Smarter event suggestions** — GPS movement is compared against each event's running location center, reducing accidental bridging between nearby places and preventing all-day photo chains from staying in one event; manual Both-mode splits require both a time gap and movement
- **Event navigator** — sidebar lists each event with its name, capture-local date and time, duration, and selected/total photo count, sorted and numbered by the same displayed capture time
- **Capture-local event ordering** — curation clusters, event ranges, durations, and grid order use the same capture-local time key shown in the UI so adjacent events do not appear to overlap by displayed timestamp
- **Burst stack detection** — photos taken within 3 seconds of each other are grouped into a stack; the largest file (proxy for sharpest) is marked as the primary frame
- **Grid selection UI** — 160×120 pt thumbnails with aspect-ratio fill; selected photos shown at full opacity with a blue border and checkmark; unselected photos dimmed to 50%
- **Curation filename visibility** — each curation thumbnail shows the source filename so large selections can be verified without opening every photo preview
- **Curation filename stability** — curation thumbnails use filenames captured during ingestion instead of querying Photos resources during SwiftUI rendering
- **Spacebar curation selection** — press Space in the curation grid or preview window to select or unselect the focused photo while reviewing an event
- **Event rename** — double-click or use the Rename button to give events meaningful names (e.g. "Sunrise hike")
- **Create posts from curation** — exports selected photos to the configured static images directory, opens a separate post editor window with image refs preloaded, uses the event's displayed capture-local day for the post filename prefix, and keeps the curation workspace open for repeated post creation
- **Curation image subpaths** — curated-photo posts and photo-only exports write selected images and markdown URLs under the configured Static image subpath template such as `YYYY/MM`
- **Curation post save reliability** — posts created from already-exported curation photos save without deleting or recopying the selected image files
- **Curation event switching stability** — thumbnail location lookups use a concurrency-safe geocode cache so switching between GPS-heavy events does not crash the app
- **Date-range curation map** — map mode can switch between the selected event and every GPS-tagged photo in the loaded date range; selecting a range pin jumps back to the matching event photo
- **Main editor draft recovery** — drag-and-drop and New Post drafts are autosaved so unfinished photo selections and markdown can be resumed after app restart or update
- **Street-level curation locations** — GPS photo labels prefer landmarks, street names, neighborhoods, city, and state when Apple reverse geocoding provides them
- **Photos-only curation export** — `⌘E` exports selected event photos without creating a post, applies the chosen blog profile's resize/EXIF settings, and prompts for a blog only when configured resize caps differ; `⌘N` creates a post from the same selection
- **Start screen return** — the curation toolbar's Start button returns to the welcome screen for drag-and-drop posts while preserving the loaded curation session, with Resume Curation kept separate from starting a new scan
- **Editable date range** — the curation toolbar calendar action reopens the current Photos-library date range with explicit `yyyy-MM-dd` fields and the no-location timezone option, then rescans and reclusters photos after confirmation
- **Side-by-side date fields** — the Photos-library date range picker places From and To controls in one row so calendar popovers do not hide the other date input
- **Stable date range picker layout** — no-location timezone controls stay visible in the Photos-library date range picker so helper text is not hidden behind a collapsing Advanced section
- **Keyboard shortcut** — `⌘K` opens the curation folder picker from the welcome screen; `⌘E` exports selected event photos; `⌘N` creates a post from the active event selection; Space toggles the focused photo selection in curation grid and preview

---

## Photos & Image Import

- **Drag & drop from Photos.app** — uses `NSFilePromiseReceiver` to handle Photos.app file promises
- **Drag & drop from Finder** — plain file URL drops also supported
- **Video file support** — drag `.mp4`, `.mov`, or `.webm` from Finder; inserts a Hugo `{{< video >}}` shortcode and copies the file to the static directory; preview panel shows a film-strip placeholder
- **EXIF date prefix** — filenames derived from `DateTimeOriginal` (e.g. `2026-03-05-photo.jpg`)
- **EXIF timezone preservation** — curation and drag-and-drop imports share the same parser for `OffsetTimeOriginal`, `SubSecTimeOriginal`, and inline EXIF timezone offsets; curation prefers original/base Photos resources, shows date-filter diagnostics for ambiguous Photos-library rows, uses original metadata GPS when PhotoKit omits location, supports manual UTC offsets for no-GPS/no-timezone Photos, trusts camera-local EXIF time when GPS is absent, and falls back to Photos' own date when EXIF is missing or GPS-assumed EXIF conflicts with Photos
- **Non-EXIF date fallback** — screenshots and downloaded images get their date from `PHAsset.creationDate` (Photos access required), file creation date, or today
- **Sort by filename** — photos dropped in the same session are sorted by filename ascending, preserving capture sequence
- **Duplicate photo prevention** — the same filename dropped twice is silently ignored
- **Import progress overlay** — frosted-glass overlay with `x / y` counter and progress bar during photo import
- **Photo strip in editor** — horizontal thumbnail strip above the markdown editor; shows all photos in the current post at a glance
- **Add photos while editing** — drag more photos onto the editor window or click the `+` button to open a file picker; new refs appended to the body without overwriting edits
- **Remove photos while editing** — hover a thumbnail and click × (or right-click → Remove Photo) to remove a photo; staging file is kept until Reset so `Cmd+Z` can restore the ref
- **Orphaned photo indicator** — thumbnails whose refs were manually deleted from the markdown body are greyed out in the strip

---

## Image Export

- **Image resize cap** — set a max long-edge dimension per profile; images exceeding the limit are downscaled while preserving aspect ratio
- **Curation photo export** — selected curation photos can be exported without creating a post, using the target blog profile's resize and EXIF stripping settings
- **EXIF metadata stripping** — GPS coordinates and device info removed from images on export (on by default); preserves `DateTimeOriginal` for filename generation only
- **Image file permissions** — exported images set to `0644` so web servers (nginx, Apache) can serve them
- **Subpath templates** — configurable date-based subdirectories using `YYYY`, `MM`, `DD` tokens; separate templates for content posts and static images

---

## Categories & Taxonomy

- **Chip-based category editor** — pick from known categories or type a new one inline; written to `categories:` frontmatter in real time
- **Tags field** — same chip UI as categories; written to `tags:` frontmatter
- **Scan Posts** — scans all `.md` files in the content directory and collects every `categories:` and `series:` value
- **Auto-scan** — background scan every 30 minutes while the app is running; toggle per profile in Settings
- **Taxonomy manager** — Settings → General → Manage…; aggregates all categories, tags, and series across the site with post counts; rename a term or merge two terms into one with bulk frontmatter rewriting across all affected files

---

## Publishing

- **Save to local Hugo repo** — writes `YYYY-MM-DD-slug.md` and copies images to the configured static directory
- **Auto git commit on Save** — per-profile toggle; runs `git add -A && git commit && git push` in the blog root after each successful Save; commit message template supports `{{title}}`; success/error shown inline in the editor footer
- **Preview current draft** — Preview saves locally without git automation, starts the configured Hugo server if needed, and opens the saved post in the browser

---

## Settings & Profiles

- **Multi-blog profiles** — each profile stores name, blog root, content path, images path, subpath templates, categories, git automation settings, image export settings, and custom frontmatter fields
- **Settings export / import** — transfer all profiles to another Mac via a JSON file
- **Image URL prefix** — auto-derived from blog root and static images path; no manual configuration needed
- **Live path preview** — shows the resolved content and image paths as subpath templates change

---

## Keyboard Shortcuts

- **`⌘N` — New Post** — start a blank text post from the welcome screen
- **`⌘B` — Browse Posts** — open the post list from the welcome screen
- **`⌘S` — Save** — save the current post (available in the editor)
- **Check for Updates** — Photolog menu bar item; shows a popup with update status and a Download button when a new version is available

---

## App & Distribution

- **Photolog branding** — app display name, build artifact, release packaging, and public documentation use the Photolog name
- **OTA updates** — Settings → Updates checks GitHub Releases; one-click download and install via Archive Utility
- **Release Notes** — Settings → Updates links to the release notes page
- **What's New sheet** — shown automatically on first launch of each new version; lists all changes since the last-seen version
- **Tag scanning** — Scan Posts collects tags from existing markdown files; tag suggestions appear in the post editor menu alongside categories
- **Share Extension** — trigger the app from the Photos.app Share sheet; photos exported and app opened automatically
- **Theme switcher** — System / Light / Dark; fully adaptive warm-cream / dark-charcoal palette
- **Quit on window close** — closing the main window also dismisses Settings and quits the app
