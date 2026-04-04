# Folio — Change History

---

## Released

### v1.16.6
- External-editor reload: add 150 ms debounce inside FileWatcher to coalesce rapid flush events from direct-write editors, preventing partial-content flicker

### v1.16.5
- Fix external-editor live reload: also watch .rename/.delete events so atomic-save editors (VSCode, Neovim, etc.) trigger a reload; re-opens the file after each event to track the new inode

### v1.16.4
- Fix OTA "Quit & Install": write update script to /tmp, run via nohup for true process detachment, strip quarantine xattr so macOS doesn't block the relaunched app

### v1.16.3
- Live reload from external editor — editor body refreshes automatically when the markdown file is modified outside Folio (e.g. in VSCode or Neovim)

### v1.16.2
- Fix OTA install: "Quit & Install" now correctly replaces the app bundle — previously `cp -Rf` nested the new app inside the old one (because the destination directory already existed) so the update was silently discarded and the old version relaunched

### v1.16.1
- Image resize cap now defaults to 1024 px (long edge) and is enabled for all new profiles — previously the cap was off by default

### v1.16.0
- Video support: drag-and-drop `.mp4`, `.mov`, and `.webm` files from Finder; inserts a Hugo `{{< video >}}` shortcode at the cursor position and copies the file to the static directory on save; preview panel shows a film-strip placeholder (closes #29)

### v1.15.4
- Fix: OTA auto-update now works — removed App Sandbox from the main app so the install script can replace Folio.app in place (sandbox blocked the cp command silently, causing the old app to relaunch)

### v1.15.3
- Settings: renamed "General" tab to "Blog"

### v1.15.2
- OTA update: after downloading, Folio extracts the zip automatically and shows a "Quit & Install" button; the app quits, replaces itself in-place, and relaunches without any manual steps

### v1.15.1
- Fix: re-editing an existing post then discarding no longer deletes the post files — "Reset" is now "Discard Changes" when re-editing and only closes the editor without touching files
- Fix: opening an existing post from Browse Posts no longer inherits the previous session's cancel record, preventing accidental deletion via "Cancel last post"

### v1.15.0
- Keyboard shortcuts: `⌘N` New Post, `⌘B` Browse Posts, `⌘S` Save (replaces `⌘⇧↩`), `⌘⇧U` Publish (closes #35)
- Check for Updates: new Folio menu bar item; shows a popup with current status and a Download button when an update is available (closes #35)

### v1.14.0
- Editor performance: preview panel now debounces updates (300 ms after last keystroke) so typing stays fast with long posts (closes #34)

### v1.13.0
- Taxonomy manager: view all categories, tags, and series with post counts; rename or merge terms across every post from Settings → General (closes #21)

### v1.12.1
- Fix: post list rows are now single-line and compact (date, title, category chips on one row)
- Fix: split-view divider now correctly resizes editor and preview panels

### v1.12.0
- Post list view: browse all existing posts in the content directory, sorted by date; tap any row to open it for re-editing (closes #15)

### v1.11.0
- Settings → Git: per-profile toggle to auto git commit & push on Save, with a customisable commit message template (`{{title}}` token) — works with any remote (closes #22)

### v1.10.2
- Settings → Image Export: "Fix Orientation" button corrects rotation on already-exported images in staticImagesPath in-place

### v1.10.1
- Fix: exported images now respect EXIF orientation — photos taken in portrait or upside-down are correctly rotated when stripped or resized

### v1.10.0
- Preview button: launch `hugo server` and open the current post in the browser before publishing — hugo path configurable per profile in Settings (closes #18)

### v1.9.0
- Settings: auto-read Hugo config (hugo.toml/yaml/json, config.toml/yaml/json) when Blog Root is set — pre-fills Content Path and Images Path from contentDir/staticDir (closes #24)

### v1.8.9
- Fix: What's New popup no longer appears empty — skipped silently when no release notes exist for intermediate versions

### v1.8.8
- Settings: Tags section shows count instead of chip list — categories and series still editable as chips

### v1.8.7
- Fix: BlogProfile decode now uses custom init(from:) with decodeIfPresent — property-level defaults are ignored by Swift's synthesized Codable decoder, causing keyNotFound for missing fields in old data

### v1.8.6
- Debug: NSLog blogProfiles load result on startup (NSLog appears in Console.app unlike print)

### v1.8.5
- Debug: log blogProfiles load result on startup to diagnose migration issues

### v1.8.4
- Fix: Blogger → Folio migration now works — several fields missing from old data (autoScanEnabled, customFrontmatterFields, stripEXIF, knownTags) caused JSON decode to fail silently; all fields now have property-level defaults

### v1.8.3
- Fix: Blogger → Folio migration failed silently — knownTags missing from old data caused JSON decode to fail, skipping profile migration entirely

### v1.8.2

### v1.8.1
- Scan Posts now collects tags from existing posts — tag suggestions appear in the post editor menu; Tags section added to Settings (closes #13)
- Fix: Series (and Categories) section stays empty after Scan Posts — draft was not refreshed from updated profile after scan completed
- Fix: Blog settings lost after updating from Blogger to Folio — profiles are now auto-migrated from the old app group on first launch

### v1.8
- What's New sheet on first launch of each new version — shows changes since the last-seen version (closes #32)

### v1.7
- Rename app from Blogger to Folio — new bundle ID `com.folio.app`, app group `group.com.folio.app`, URL scheme `folio://`
- GitHub Pages release notes site at https://cychong47.github.io/folio/ — auto-generated from HISTORY.md on every CI push
- Settings → Updates now shows a "Release Notes" link

### v1.6
- Strip GPS & device EXIF metadata on image export (closes #30) — new Privacy toggle in Settings → Image Export (on by default)

### v1.5
- Cap exported image dimensions per profile (closes #28) — max long-edge setting in Settings → Image Export; images downscaled while preserving aspect ratio

### v1.4
- Custom frontmatter fields per blog profile (closes #23) — define extra key/value pairs in Settings → Custom Frontmatter; appended to every post's frontmatter at Save time

### v1.3
- Text + image preview panel (closes #14) — right panel now shows typed text and images in document order so you can see how captions relate to photos

### v1.2
- Auto-scan for categories and series (closes #13) — background scan every 30 minutes; manual "Scan Posts" button still available; scan timing shown after each run

### v1.1
- OTA update flow: CI now publishes a GitHub Release on every push so the in-app updater finds it (closes #12)
- Delete local post files automatically after GitHub publish (closes #11)
- Empty default title with red-border validation — Save is blocked until title is filled (closes #10)
- Sort drag-and-drop photos by filename ascending, preserving capture order (closes #9)
- Non-EXIF image dates (screenshots) resolved via PHAsset.creationDate when Photos access is granted

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

---

## Upcoming

See open issues at https://github.com/cychong47/folio/issues
