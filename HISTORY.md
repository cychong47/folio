# Folio — Change History

---

## Released

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
