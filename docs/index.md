---
layout: default
title: Release Notes
description: What's new in each version of Folio for macOS
---

# Folio for macOS

A native macOS app for creating [Hugo](https://gohugo.io/) blog posts from photos.
Drag photos from Photos.app or Finder, write a post in the split-view editor, and publish directly to your Hugo site via the GitHub API.

**[View all features →](features)**   &nbsp;|&nbsp;   **[Download latest release →](https://github.com/cychong47/folio/releases/latest)**

---

# Release Notes

<!-- AUTO-GENERATED below this line — edit HISTORY.md instead -->

### v1.20.9

- Fix no-GPS photo timestamps — EXIF `OffsetTimeOriginal` is now honored when parsing `DateTimeOriginal`, so exported or folder-scanned photos without GPS keep the correct capture instant

---

### v1.20.8

- Smarter event suggestions — photo clustering now anchors spatial splits to each event's running GPS centroid and keeps manual Both-mode splits from breaking up long stops without movement

---

### v1.20.7

- Rename app to Photolog — app display name, product name, build artifact, and public documentation now use the Photolog brand

---

### v1.20.6

- Replace spaces with underscores in exported filenames — photos with spaces in their camera-roll name (e.g. "Photo 2026-03-15.jpg") are saved as "Photo_2026-03-15.jpg" so filenames are URL-safe in the blog

---

### v1.20.5

- Export button in curation action bar — "Export" button alongside the keyboard shortcut so selection can be exported without memorising the hotkey; curation view stays open after export so you can select different photos and create another post without re-opening the date picker

---

### v1.20.4

- Adjustable thumbnail size in curation grid — small↔large photo icon slider in the action bar scales thumbnails from 100 px to 320 px; grid reflows automatically

---

### v1.20.3

- Fix exported photos rotated 90° — curation export now bakes EXIF orientation into pixel data (via CIImage.oriented) before stripping metadata or resizing, matching the fix already present in the regular drag-and-drop export path

---

### v1.20.2

- Preserve original filename on export — exported images now keep their camera-roll name (e.g. IMG_1234.jpg) instead of being renamed to date-event-seq.jpg; only the extension changes when HEIC is converted to JPEG

---

### v1.20.1

- Fix export failing with "volume is read only" — upfront guard now catches an empty or system-volume path before attempting any writes; error alert includes an "Open Settings" button to fix the path immediately

---

### v1.20.0

- Create New Post from curation — after exporting, the "Create New Post" button opens the post editor with the exported photos pre-loaded and image refs already in the markdown body
- Fix map pin tumbling — pins are now cached in @State and only rebuilt when the cluster changes (not on every selection toggle); PhotoPin is fully static with no dynamic state, which prevents MapKit from re-presenting annotations

---

### v1.19.9

- Fix map pin tumbling repeatedly — icon name no longer swaps between camera.fill and checkmark (selection shown by fill color instead); `.transaction { animation = nil }` suppresses all animation on the pin, including MapKit re-presentation
- Split panel: sub-event legend now shows a colored rectangle chip with photo count per group (e.g. "32 photos") so it's clear which colored strip on the thumbnails maps to which sub-event

---

### v1.19.8

- Split Event — "Split Event" button in the curation action bar opens a panel with Time / Location / Both mode selector and live sliders; photos are color-coded by sub-event in real time as thresholds are adjusted; "Apply Split" breaks the cluster into separately-named events

---

### v1.19.7

- Fix map view camera icon tumbling repeatedly — removed withAnimation from region update; MapKit animates region changes itself, and the implicit animation was bleeding into MapAnnotation content and spinning the icon
- Event sidebar now shows total photo count ("278 photos") as primary info; selected count appears in accent colour only when photos are selected

---

### v1.19.6

- Map view in photo curation — grid/map toggle in the event action bar; photos with GPS appear as pins on a MapKit map; tapping a pin opens the full-size detail sheet; map auto-fits to the event bounding box; photos without GPS show a count badge

---

### v1.19.5

- Fix photo timestamps showing in device timezone (KST) instead of where the photo was taken — reverse-geocoding now also captures CLPlacemark.timeZone and uses it to format timestamps in the grid and detail sheet; photos without GPS continue to show device-local time

---

### v1.19.4

- Fix curation grid: photos no longer appear dimmed — removed 50% opacity on unselected thumbnails; selection is indicated by the accent border and checkmark alone

---

### v1.19.3

- Double-click a photo to open it full-size — sheet shows the photo at up to 2400 px with ←/→ keyboard navigation and S to toggle export selection
- Favorite toggle in the detail sheet — heart button marks/unmarks the photo in Photos.app via PHPhotoLibrary; F key shortcut; heart badge overlaid on thumbnail for already-favourited photos

---

### v1.19.2

- Screenshots now split into separate events from regular photos — clustering partitions by media type before grouping by time + location
- Screenshot events are clustered by time only (no GPS) and labelled "Screenshots" in the event list
- Each photo thumbnail now shows its timestamp and reverse-geocoded location (city, region) below the image; screenshots show a "Screenshot" label instead

---

### v1.19.1

- Fix photo curation returning no results — CI now ad-hoc signs the app binary with the Photos entitlement embedded; photolibraryd checks the code signature (not just TCC) before serving assets, so an unsigned binary always got 0 results

---

### v1.19.0

- Fix photo curation returning no results — call PHPhotoLibrary.requestAuthorization inside the GCD fetch block to open the XPC session with photolibraryd before fetching; authorizationStatus alone does not establish the connection so fetchAssets silently returned 0
- Curation empty state now shows Photos library path for easier debugging

---

### v1.18.9

- Fix photo curation returning no results — PHAsset.fetchAssets now runs on an explicit DispatchQueue.global GCD thread; Swift cooperative thread pool (Task.detached) and @MainActor both silently return 0 because photolibraryd's XPC channel requires a real GCD-backed thread

---

### v1.18.8

- Fix photo curation returning no results — PHAsset.fetchAssets now runs via Task.detached (off the Swift actor), matching the GCD context PhotoKit's XPC daemon requires; @MainActor context silently broke the photolibraryd connection

---

### v1.18.7

- Fix photo curation returning no results — move all PHAsset fetching onto the MainActor directly instead of via background thread + MainActor.run, which was silently returning empty results

---

### v1.18.6

- Curation empty state: diagnostic text is now selectable; explains when Photos library is empty on this Mac

---

### v1.18.5

- Curation empty state now shows total library photo count alongside date-range count to distinguish "wrong date range" from "Photos not accessible"

---

### v1.18.4

- Photo curation empty state shows authorization status and raw asset count so the cause of "no photos found" is visible without Console.app

---

### v1.18.3

- Fix photo curation date range: dates are now normalised to start/end of day so photos early on the first day are not missed; default range widened to 30 days; empty state shows exactly which dates were searched and offers "Try Different Dates"

---

### v1.18.2

- Fix photo curation returning no results — PHAsset.fetchAssets now runs on the main thread; removed includeAssetSourceTypes filter that silently excluded photos on macOS

---

### v1.18.1

- Batch progress updates during photo ingestion — reduces main-thread hops from per-photo to per-10, keeping large date ranges (e.g. a full month) responsive

---

### v1.18.0

- Photo Curation Workspace — pick a date range from your Photos library; photos are auto-grouped into timed events using spatio-temporal clustering; keyboard-driven grid UI to select/deselect shots; export selected photos with markdown snippet for the blog

---

### v1.17.0

- Photo strip in editor — horizontal thumbnail row above the markdown editor; hover to reveal × remove button or right-click for context menu
- Add photos while editing — drag onto the editor window or click `+` to open file picker; new refs appended without overwriting existing edits
- Remove photos while editing — deferred staging-file deletion preserves `Cmd+Z` undo of the ref line
- Orphaned thumbnail indicator — thumbnails greyed out when their ref is manually deleted from the markdown body

---

### v1.16.11

- Fix "Quit & Install" in menu-bar update popup — sheet modal state blocked `NSApp.terminate`; now dismisses the sheet before initiating the update

---

### v1.16.10

- Fix "New Post" link not opening the editor — `PendingPost.isEmpty` ignored `slug`, so setting it on "New Post" click had no effect

---

### v1.16.9

- Edit view: show "Cancel" instead of "Discard Changes" when reopening an existing post with no edits; "Discard Changes" (with confirmation) only appears once the title or body has been modified

---

### v1.16.8

- Fix images with trailing whitespace (markdown line-break `  `) not rendering in edit view — imageRefRegex `$` anchor rejected lines ending with spaces

---

### v1.16.7

- Fix static-images subpath template ignored on drag-drop: DropTargetView was reading stale flat UserDefaults keys that are never written; now decodes the active BlogProfile from `blogProfiles` JSON so the configured subpath (e.g. YYYY/MM) is applied correctly

---

### v1.16.6

- External-editor reload: add 150 ms debounce inside FileWatcher to coalesce rapid flush events from direct-write editors, preventing partial-content flicker

---

### v1.16.5

- Fix external-editor live reload: also watch .rename/.delete events so atomic-save editors (VSCode, Neovim, etc.) trigger a reload; re-opens the file after each event to track the new inode

---

### v1.16.4

- Fix OTA "Quit & Install": write update script to /tmp, run via nohup for true process detachment, strip quarantine xattr so macOS doesn't block the relaunched app

---

### v1.16.3

- Live reload from external editor — editor body refreshes automatically when the markdown file is modified outside Folio (e.g. in VSCode or Neovim)

---

### v1.16.2

- Fix OTA install: "Quit & Install" now correctly replaces the app bundle — previously `cp -Rf` nested the new app inside the old one (because the destination directory already existed) so the update was silently discarded and the old version relaunched

---

### v1.16.1

- Image resize cap now defaults to 1024 px (long edge) and is enabled for all new profiles — previously the cap was off by default

---

### v1.16.0

- Video support: drag-and-drop `.mp4`, `.mov`, and `.webm` files from Finder; inserts a Hugo `{{< video >}}` shortcode at the cursor position and copies the file to the static directory on save; preview panel shows a film-strip placeholder (closes #29)

---

### v1.15.4

- Fix: OTA auto-update now works — removed App Sandbox from the main app so the install script can replace Folio.app in place (sandbox blocked the cp command silently, causing the old app to relaunch)

---

### v1.15.3

- Settings: renamed "General" tab to "Blog"

---

### v1.15.2

- OTA update: after downloading, Folio extracts the zip automatically and shows a "Quit & Install" button; the app quits, replaces itself in-place, and relaunches without any manual steps

---

### v1.15.1

- Fix: re-editing an existing post then discarding no longer deletes the post files — "Reset" is now "Discard Changes" when re-editing and only closes the editor without touching files
- Fix: opening an existing post from Browse Posts no longer inherits the previous session's cancel record, preventing accidental deletion via "Cancel last post"

---

### v1.15.0

- Keyboard shortcuts: `⌘N` New Post, `⌘B` Browse Posts, `⌘S` Save (replaces `⌘⇧↩`), `⌘⇧U` Publish (closes #35)
- Check for Updates: new Folio menu bar item; shows a popup with current status and a Download button when an update is available (closes #35)

---

### v1.14.0

- Editor performance: preview panel now debounces updates (300 ms after last keystroke) so typing stays fast with long posts (closes #34)

---

### v1.13.0

- Taxonomy manager: view all categories, tags, and series with post counts; rename or merge terms across every post from Settings → General (closes #21)

---

### v1.12.1

- Fix: post list rows are now single-line and compact (date, title, category chips on one row)
- Fix: split-view divider now correctly resizes editor and preview panels

---

### v1.12.0

- Post list view: browse all existing posts in the content directory, sorted by date; tap any row to open it for re-editing (closes #15)

---

### v1.11.0

- Settings → Git: per-profile toggle to auto git commit & push on Save, with a customisable commit message template (`{{title}}` token) — works with any remote (closes #22)

---

### v1.10.2

- Settings → Image Export: "Fix Orientation" button corrects rotation on already-exported images in staticImagesPath in-place

---

### v1.10.1

- Fix: exported images now respect EXIF orientation — photos taken in portrait or upside-down are correctly rotated when stripped or resized

---

### v1.10.0

- Preview button: launch `hugo server` and open the current post in the browser before publishing — hugo path configurable per profile in Settings (closes #18)

---

### v1.9.0

- Settings: auto-read Hugo config (hugo.toml/yaml/json, config.toml/yaml/json) when Blog Root is set — pre-fills Content Path and Images Path from contentDir/staticDir (closes #24)

---

### v1.8.9

- Fix: What's New popup no longer appears empty — skipped silently when no release notes exist for intermediate versions

---

### v1.8.8

- Settings: Tags section shows count instead of chip list — categories and series still editable as chips

---

### v1.8.7

- Fix: BlogProfile decode now uses custom init(from:) with decodeIfPresent — property-level defaults are ignored by Swift's synthesized Codable decoder, causing keyNotFound for missing fields in old data

---

### v1.8.6

- Debug: NSLog blogProfiles load result on startup (NSLog appears in Console.app unlike print)

---

### v1.8.5

- Debug: log blogProfiles load result on startup to diagnose migration issues

---

### v1.8.4

- Fix: Blogger → Folio migration now works — several fields missing from old data (autoScanEnabled, customFrontmatterFields, stripEXIF, knownTags) caused JSON decode to fail silently; all fields now have property-level defaults

---

### v1.8.3

- Fix: Blogger → Folio migration failed silently — knownTags missing from old data caused JSON decode to fail, skipping profile migration entirely

---

### v1.8.2



---

### v1.8.1

- Scan Posts now collects tags from existing posts — tag suggestions appear in the post editor menu; Tags section added to Settings (closes #13)
- Fix: Series (and Categories) section stays empty after Scan Posts — draft was not refreshed from updated profile after scan completed
- Fix: Blog settings lost after updating from Blogger to Folio — profiles are now auto-migrated from the old app group on first launch

---

### v1.8

- What's New sheet on first launch of each new version — shows changes since the last-seen version (closes #32)

---

### v1.7

- Rename app from Blogger to Folio — new bundle ID `com.folio.app`, app group `group.com.folio.app`, URL scheme `folio://`
- GitHub Pages release notes site at https://cychong47.github.io/folio/ — auto-generated from HISTORY.md on every CI push
- Settings → Updates now shows a "Release Notes" link

---

### v1.6

- Strip GPS & device EXIF metadata on image export (closes #30) — new Privacy toggle in Settings → Image Export (on by default)

---

### v1.5

- Cap exported image dimensions per profile (closes #28) — max long-edge setting in Settings → Image Export; images downscaled while preserving aspect ratio

---

### v1.4

- Custom frontmatter fields per blog profile (closes #23) — define extra key/value pairs in Settings → Custom Frontmatter; appended to every post's frontmatter at Save time

---

### v1.3

- Text + image preview panel (closes #14) — right panel now shows typed text and images in document order so you can see how captions relate to photos

---

### v1.2

- Auto-scan for categories and series (closes #13) — background scan every 30 minutes; manual "Scan Posts" button still available; scan timing shown after each run

---

### v1.1

- OTA update flow: CI now publishes a GitHub Release on every push so the in-app updater finds it (closes #12)
- Delete local post files automatically after GitHub publish (closes #11)
- Empty default title with red-border validation — Save is blocked until title is filled (closes #10)
- Sort drag-and-drop photos by filename ascending, preserving capture order (closes #9)
- Non-EXIF image dates (screenshots) resolved via PHAsset.creationDate when Photos access is granted

---

### v1.0

- Split-view post editor: monospaced markdown editor on the left, photo gallery on the right
- Drag & drop photos from Photos.app (NSFilePromiseReceiver) and Finder
- Hugo frontmatter auto-generation: title, date (with time + timezone), categories, tags, series
- Live slug auto-generated from title; editable independently
- Filename format: `YYYY-MM-DD-slug.md` derived from EXIF DateTimeOriginal
- GitHub publish via REST API — no git binary required; supports GitHub, Codeberg, Gitea
- Multi-blog profiles: each profile stores paths, subpath templates, categories, GitHub settings
- Settings export / import as JSON for moving to another Mac
- OTA updates: Settings → Updates checks GitHub releases, downloads and opens zip
- Share Extension from Photos.app
- Categories management: Scan Posts collects from existing markdown files; chip-based editor
- Subpath templates: YYYY, MM, DD tokens for content and images directories
- Theme switcher: System / Light / Dark with warm-cream / dark-charcoal palette
- Duplicate photo prevention, import progress overlay, image permissions (0644)
- Quit on window close
