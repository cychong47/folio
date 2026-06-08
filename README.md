# Photolog

A native macOS app for creating [Hugo](https://gohugo.io/) blog posts from photos.
Drag photos from Photos.app or Finder, write a post in the split-view editor, and save directly to your Hugo site repo.

---

## Features

- **Drag & drop from Photos.app or Finder** — uses `NSFilePromiseReceiver` to handle Photos.app drags
- **Welcome action launcher** — the start window presents Drag Photos, New Post, Browse Posts, and Curate Photos as large icon tiles for faster first-step selection
- **Compact welcome window** — the start window opens shorter around the large action tiles while work modes keep a roomier editor-sized minimum
- **Welcome window size restoration** — returning to or relaunching the welcome screen restores a compact size that still leaves room for the Photos access banner
- **Photolog branding** — app display name, build artifact, and release packaging use the Photolog name
- **Video file support** — drag `.mp4`, `.mov`, or `.webm` files from Finder; inserts a Hugo `{{< video >}}` shortcode and copies the file to the static directory on save
- **EXIF date prefix** — filenames derived from `DateTimeOriginal` (e.g. `2026-03-05-IMG_1234.jpg`)
- **EXIF timezone preservation** — photo curation and drag-and-drop import share the same EXIF parser for separated offsets, subsecond fields, and inline timezone offsets; curation prefers original/base Photos resources, shows selected-event timestamp and date-filter diagnostics, uses original metadata GPS as a fallback when PhotoKit omits location, trusts camera-local EXIF time when GPS is absent, supports a manual UTC offset for no-GPS/no-timezone Photos, and falls back to Photos' own date only when EXIF is missing or GPS-assumed EXIF conflicts with Photos
- **Camera model display** — curation thumbnails and detail views show the parsed camera make/model immediately after each photo timestamp
- **Autosaved post drafts** — separate editor-window drafts persist unsaved post metadata and selected photo references so the latest draft can be resumed after restart or update
- **Split-view post editor** — markdown editor on the left, live text+image preview on the right showing content in document order
- **Preview filename captions** — the post editor preview shows each media filename below its rendered image or video placeholder for editing reference only
- **External editor live reload** — body text refreshes automatically when the post file is modified in an external editor (VSCode, Neovim, etc.)
- **Hugo frontmatter** — auto-generated with title, date, categories, and image references
- **Live slug** — filename slug auto-generated from title and kept in sync as you type
- **Title validation** — Save is blocked with a red-bordered title field when title is left empty
- **Subpath templates** — `YYYY/MM/DD` tokens for date-based content and image directories
- **Categories & tags management** — scan existing posts to collect categories and tags; pick or add inline in the editor via suggestion menu
- **Image URL preview** — live preview of the effective image URL in Settings
- **Import progress indicator** — frosted-glass overlay with progress bar during photo import
- **Duplicate photo prevention** — same filename dropped twice is silently ignored
- **Image file permissions** — copied images set to `0644` so web servers (nginx) can serve them
- **Multi-blog profiles** — manage multiple Hugo sites; each profile has its own paths, subpath templates, categories, and custom frontmatter fields; switch active blog in the post editor
- **Custom frontmatter fields** — define extra key/value pairs per profile (e.g. `author`, `description`) appended to every post's frontmatter
- **Image resize cap** — set a max long-edge dimension per profile; images are downscaled on export to keep the Hugo site lean
- **EXIF metadata stripping** — GPS coordinates and device info are removed from images on export by default to protect user privacy
- **Settings export / import** — transfer all profiles and configuration to another Mac via a JSON file
- **Theme switcher** — System / Light / Dark, fully adaptive warm-cream / dark-charcoal palette
- **Tabbed Settings window** — General (master-detail) and Appearance tabs; categories management merged into the General detail panel
- **Quit on window close** — closing the main window also dismisses Settings and quits the app
- **Post list view** — "Browse Posts" on the welcome screen lists all existing posts in the content directory sorted by date with date, draft, series, and category metadata; select any post to re-edit it in a separate editor window while Browse stays open
- **Auto git commit on Save** — per-profile toggle in Settings; runs `git add -A && git commit && git push` in the blog root after each Save; commit message template supports `{{title}}`
- **Save-before-preview** — Preview saves the current draft locally without git automation before starting Hugo and opening the post in the browser
- **Taxonomy manager** — Settings → General → Manage…; lists all categories, tags, and series with post counts; rename a term or merge two terms across every post in the content directory
- **Photo Curation Workspace** — scan a vacation photo folder (`⌘K`); Photos-library curation prefers original/base asset resources for metadata, shows camera make/model next to each photo timestamp, shows the selected event's resource plus timestamp and date-filter decisions in the sidebar, submits explicit `yyyy-MM-dd` date fields, can apply a manual UTC offset to no-GPS/no-timezone Photos, uses capture-local date and time from separated EXIF offsets, subsecond EXIF fields, inline EXIF offsets, GPS-derived timezones from PhotoKit or original metadata, camera-local EXIF when GPS is absent, or Photos' own date when EXIF is missing, sorts and numbers event rows by the displayed capture time, uses the visible event day for created post filenames, and keeps the date range editable from the curation toolbar
- **Curation filename visibility** — curation grid thumbnails show each photo filename so large selections can be checked without opening every preview
- **Curation filename stability** — curation thumbnails use filenames captured during ingestion instead of querying Photos resources during rendering
- **Curation image subpaths** — curated-photo posts and photo-only exports write selected images and markdown URLs under the configured Static image subpath template such as `YYYY/MM`
- **Curation post save reliability** — posts created from already-exported curation photos save without deleting or recopying the selected image files
- **Curation event switching stability** — thumbnail location lookups use a concurrency-safe geocode cache so switching between GPS-heavy events does not crash the app
- **Street-level curation locations** — GPS photo labels prefer landmarks, street names, neighborhoods, city, and state when Apple reverse geocoding provides them
- **Photos-only curation export** — `⌘E` exports selected event photos without creating a post, applying blog resize/EXIF settings and prompting for a blog only when configured resize caps differ
- **Spacebar curation selection** — press Space in the curation grid or preview window to select or unselect the focused photo
- **Capture-local event ordering** — curation clusters and displays event photo ranges with the same capture-local time order shown in the UI
- **Stable Photos date picker** — the Photos-library date range window keeps no-location timezone controls visible so helper text is not hidden behind an expanding Advanced section
- **Smarter event suggestions** — event generation compares GPS movement against each event's running location center and caps auto-events at 4 hours so long photo chains do not merge a whole day
- **Keyboard shortcuts** — `⌘N` New Post or Create Post in curation, `⌘E` Export Photos in curation, Space toggles curation photo selection, `⌘B` Browse Posts, `⌘K` Curate Photos, `⌘S` Save
- **Check for Updates** — Photolog menu bar item; shows a popup with update status and a one-click Download button when a new version is available
- **OTA updates** — Settings → Updates checks GitHub releases; one-click download and install via Archive Utility
- **What's New sheet** — shown automatically on first launch of each new version; lists changes since the last-seen version

---

## Usage

### 1. Configure Settings

Open **Settings** (`⌘,`) → **General** before first use. Create a blog profile for each Hugo site.

**Profile fields:**

| Field | Description | Example |
|-------|-------------|---------|
| **Name** | Friendly label for this blog | `sosa0sa` |
| **Blog Root** | Root of your Hugo site; auto-fills Content and Images paths below | `/Users/you/blog` |
| **Content** path | Hugo content/posts directory | `/Users/you/blog/content/posts` |
| **Images** path | Hugo static/images directory | `/Users/you/blog/static/images` |
| **Content subpath** | Date-based subdirectory template for posts | `YYYY/MM` → `2026/03` |
| **Images subpath** | Date-based subdirectory template for images | `YYYY/MM` → `2026/03` |

**Subpath tokens:** `YYYY` (4-digit year), `MM` (2-digit month), `DD` (2-digit day).
Leave a subpath empty to put all files flat in the root directory.

The image URL prefix (used in markdown `![]()` references) is automatically derived from the blog root and images path — no manual configuration needed.

**Categories — Scan Posts:** In Settings → **General**, select a blog profile and click **Scan Posts** to collect all existing `categories:` values from that profile's Hugo markdown files. Re-scan any time after adding posts outside the app.

**Transferring settings to another Mac:**

- **Export Settings…** — saves all profiles to a `photolog-settings.json` file you can copy anywhere.
- **Import Settings…** — restores all profiles from a previously exported JSON file.

---

### 2. Import Photos

Drag photos from **Photos.app** or **Finder** and drop them onto the app window.

- Photos are copied to a staging area while you compose the post.
- EXIF `DateTimeOriginal` is read from each photo to derive the date prefix.
- Filenames are normalised: `2026-03-05-IMG_1234.jpg`
- Duplicate photos (same filename) are ignored if dropped again.
- A progress bar is shown during import.

---

### 3. Write the Post

The editor opens automatically once photos are imported.

| Field | Description |
|-------|-------------|
| **Title** | Post title. Also auto-generates the filename slug. |
| **Filename** | `YYYY-MM-DD-slug.md` — the date prefix comes from the first photo's EXIF date. Edit the slug part freely. |
| **Categories** | Pick from known categories (populated by Scan Posts) or add a new one inline. Selections are reflected in the frontmatter immediately. |

The **left pane** is a plain-text markdown editor pre-filled with Hugo frontmatter and image references.
The **right pane** shows thumbnails of the staged photos with their filenames.

The staging folder location is shown above the photo list — click the arrow button to reveal it in Finder.

---

### 4. Save and Preview

Press **Save** (`⌘S`) to:

1. Copy photos from the staging area to `{staticImagesPath}/{resolvedSubpath}/`
2. Write the markdown file to `{contentPath}/{resolvedSubpath}/YYYY-MM-DD-slug.md`
3. Optionally run `git add -A`, `git commit`, and `git push` when Auto git commit on Save is enabled

Press **Preview** to save the current draft locally without git automation, start the configured Hugo server if needed, and open the saved post in your browser.

Press **Reset** to discard the current post and delete staged files.

---

### 5. Deploy

Run Hugo and copy the output to your server as usual:

```bash
cd /path/to/your/hugo/site
hugo
rsync -av public/ user@server:/var/www/html/
```

---

## Configuration Storage

Settings are stored in **macOS UserDefaults** as a `.plist` file — no SQLite, no custom file format.

**File location:**
```
~/Library/Group Containers/group.com.folio.app/Library/Preferences/group.com.folio.app.plist
```

**Inspect from Terminal:**
```bash
defaults read group.com.folio.app
```

**Keys stored:**

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `contentPath` | String | `""` | Hugo content/posts directory path |
| `staticImagesPath` | String | `""` | Hugo static/images directory path |
| `imageURLPrefix` | String | `/images` | URL prefix for markdown image references |
| `contentSubpath` | String | `YYYY/MM` | Subpath template under contentPath |
| `staticImagesSubpath` | String | `""` | Subpath template under staticImagesPath |
| `knownCategories` | [String] | `[]` | Categories collected from existing posts |

**Why App Group UserDefaults?**
The preference suite `group.com.folio.app` was designed to be shared between the main app and a Share Extension (so both targets can read the same settings). The data lands in `~/Library/Group Containers/` rather than the standard `~/Library/Preferences/`.

---

## Building

The project uses [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`.

### GitHub Actions (recommended)

Push to `main` — the [build workflow](.github/workflows/build.yml) runs automatically on a macOS runner, builds the app unsigned, and uploads `Photolog.zip` as a downloadable artifact.

1. Go to **Actions** → latest **Build Photolog** run → **Artifacts** → download `Photolog.zip`
2. Unzip and move `Photolog.app` to `/Applications`
3. On first launch macOS may block the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Photolog.app
   ```

### Local (no Xcode required)

```bash
# Download xcodegen
mkdir -p /tmp/xcodegen_bin
curl -L https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip \
  -o /tmp/xcodegen.zip
unzip /tmp/xcodegen.zip -d /tmp/xcodegen_bin

# Generate project and build
/tmp/xcodegen_bin/xcodegen/bin/xcodegen generate
xcodebuild -project Photolog.xcodeproj -scheme Photolog \
  -configuration Release CODE_SIGNING_ALLOWED=NO \
  -derivedDataPath build
```

---

## Project Structure

```
blogger/
├── project.yml                          # xcodegen configuration
├── .github/workflows/build.yml          # GitHub Actions CI build
├── Shared/
│   └── Constants.swift                  # App Group ID, URL scheme, UserDefaults keys
├── folio/                               # Main app target
│   ├── FolioApp.swift                   # App entry point, URL scheme handler
│   ├── ContentView.swift                # Root view (editor or welcome screen)
│   ├── Models/
│   │   ├── AppSettings.swift            # UserDefaults-backed settings (ObservableObject)
│   │   └── PendingPost.swift            # In-memory post state (ObservableObject)
│   ├── Views/
│   │   ├── PostEditorView.swift         # Split-view markdown editor + photo gallery
│   │   ├── SettingsView.swift           # Preferences window
│   │   ├── WelcomeView.swift            # Drop zone shown before photos are imported
│   │   └── DropTargetView.swift         # NSView subclass handling drag-and-drop
│   └── Services/
│       ├── PhotoExporter.swift          # EXIF reading, filename generation, file copy
│       ├── MarkdownGenerator.swift      # Frontmatter + markdown assembly + file write
│       ├── CategoryScanner.swift        # Scans .md files to extract categories
│       ├── SlugGenerator.swift          # String → URL-safe slug
│       └── SharedContainerService.swift # App Group container read/write helpers
└── FolioShareExtension/                 # Share Extension target (Photos.app integration)
    ├── ShareViewController.swift
    └── Info.plist
```

---

## Generated Frontmatter

```yaml
---
title: "My Post Title"
date: "2026-03-07T14:05:00+09:00"
draft: false
categories: ["Vancouver"]
tags: []
---

![](/images/2026/03/2026-03-07-photo1.jpg)
![](/images/2026/03/2026-03-07-photo2.jpg)
```
