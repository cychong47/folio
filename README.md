# Blogger

A native macOS app for creating [Hugo](https://gohugo.io/) blog posts from photos.
Drag photos from Photos.app or Finder, write a post in the split-view editor, and publish directly to your Hugo site.

---

## Features

- **Drag & drop from Photos.app or Finder** — uses `NSFilePromiseReceiver` to handle Photos.app drags
- **EXIF date prefix** — filenames derived from `DateTimeOriginal` (e.g. `2026-03-05-IMG_1234.jpg`)
- **Split-view post editor** — markdown editor on the left, photo thumbnails on the right
- **Hugo frontmatter** — auto-generated with title, date, categories, and image references
- **Live slug** — filename slug auto-generated from title and kept in sync as you type
- **Title validation** — Save is blocked with a red-bordered title field when title is left empty
- **Subpath templates** — `YYYY/MM/DD` tokens for date-based content and image directories
- **Categories management** — scan existing posts to collect categories; pick or add inline in the editor
- **Image URL preview** — live preview of the effective image URL in Settings
- **Import progress indicator** — frosted-glass overlay with progress bar during photo import
- **Duplicate photo prevention** — same filename dropped twice is silently ignored
- **Image file permissions** — copied images set to `0644` so web servers (nginx) can serve them
- **Multi-blog profiles** — manage multiple Hugo sites; each profile has its own paths, subpath templates, and categories; switch active blog in the post editor
- **Settings export / import** — transfer all profiles and configuration to another Mac via a JSON file
- **Theme switcher** — System / Light / Dark, fully adaptive warm-cream / dark-charcoal palette
- **Tabbed Settings window** — General (master-detail) and Appearance tabs; categories management merged into the General detail panel
- **Quit on window close** — closing the main window also dismisses Settings and quits the app
- **OTA updates** — Settings → Updates checks GitHub releases; one-click download and install via Archive Utility

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

- **Export Settings…** — saves all profiles to a `blogger-settings.json` file you can copy anywhere.
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

### 4. Publish

Press **Publish** (`⌘⇧↩`) to:

1. Copy photos from the staging area to `{staticImagesPath}/{resolvedSubpath}/`
2. Write the markdown file to `{contentPath}/{resolvedSubpath}/YYYY-MM-DD-slug.md`
3. Show the saved file path in a confirmation dialog

After confirming, staged photo files are deleted automatically.

Press **Reset** to discard the current post and delete staged files without publishing.

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
~/Library/Group Containers/group.com.blogger.app/Library/Preferences/group.com.blogger.app.plist
```

**Inspect from Terminal:**
```bash
defaults read group.com.blogger.app
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
The preference suite `group.com.blogger.app` was designed to be shared between the main app and a Share Extension (so both targets can read the same settings). The data lands in `~/Library/Group Containers/` rather than the standard `~/Library/Preferences/`.

---

## Building

The project uses [xcodegen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj`.

### GitHub Actions (recommended)

Push to `main` — the [build workflow](.github/workflows/build.yml) runs automatically on a macOS runner, builds the app unsigned, and uploads `Blogger.zip` as a downloadable artifact.

1. Go to **Actions** → latest **Build Blogger** run → **Artifacts** → download `Blogger.zip`
2. Unzip and move `Blogger.app` to `/Applications`
3. On first launch macOS may block the app. Go to **System Settings → Privacy & Security** and click **Open Anyway**, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/Blogger.app
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
xcodebuild -project Blogger.xcodeproj -scheme Blogger \
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
├── blogger/                             # Main app target
│   ├── BloggerApp.swift                 # App entry point, URL scheme handler
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
└── BloggerShareExtension/               # Share Extension target (Photos.app integration)
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
