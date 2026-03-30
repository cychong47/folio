# Blogger — Change History

---

## Released

### Welcome Screen Polish
- "New Post" inline link no longer shows a focus ring on app launch

### Full Timestamp in Frontmatter (closes #7)
- Frontmatter `date:` field now includes time and timezone offset (e.g. `2026-03-30T14:05:00+09:00`) instead of date-only
- Ensures posts published on the same day sort correctly in Hugo by time of creation

### GitHub Publish (closes #1)
- "Publish" renamed to "Save" — writes the markdown file and images to disk, stays in editor
- New "Publish" button appears after saving; commits and pushes only the saved files via the GitHub REST API (no git binary required)
- Settings → General → GitHub section: Personal Access Token, repo (`owner/repo`), branch; "Auto-detect" reads repo and branch from the blog root's `.git/config`
- Reset from the editor now also deletes already-saved files if present

### Text-only Post (closes #4)
- "New Post" button added to the welcome screen for starting a post without photos
- Default title is the current date + time (e.g. `2026-03-29 15:30:45`); user changes it before publishing
- Post date picker is available as usual to override the date

### Series Field (closes #6)
- "Series" row added to the post editor below Tags — pick from known series via the menu or type a new one
- Series is optional; omitted from frontmatter when empty; written as `series: [Name]` when set
- Settings → General now shows a "Series" section alongside Categories; both are populated by the same "Scan Posts" action

### Hidden Frontmatter + Tags Field (closes #5)
- Frontmatter is now hidden from the markdown editor; it is generated from the UI fields (title, date, categories, tags) at publish time
- Tags field added below Categories with the same chip UI — click "+" to type a tag, press Return to add it

### Editable Post Date (closes #2)
- A "Date" row with a compact date picker now appears in the post editor header
- Changing the date updates the frontmatter `date:` field, renames staged photo files to use the new date prefix, and updates all image references in the markdown body
- Falls back to the first photo's EXIF date (or today) when no override is set

### Cancel Last Post (closes #3)
- After publishing, a "Cancel last post" button appears on the welcome screen
- Canceling deletes the markdown file and copied static images written in that session only
- Starting a new post (dropping photos) dismisses the cancel option

### Build Info in About Panel
- About Blogger now shows the git commit date and short hash (e.g. `2026-03-29 (2767d18)`) injected at build time via a pre-build script

### Cleaner Frontmatter Quoting
- `title`, `categories`, and `tags` values are no longer wrapped in quotes unless YAML requires it (e.g. value contains `: `, ` #`, or flow-indicator characters)

### Settings Master-Detail Redesign
- Settings → General tab replaced with a master-detail layout: profile list on the left, full profile detail (paths + subpath templates + categories) on the right — everything about a blog in one place
- Categories tab removed; category scanning and management now live in the General tab detail panel
- Live write-back: all profile edits are saved instantly without a Save/Cancel dialog
- "Set as Active" button in the detail panel promotes any profile to the active blog
- Settings window widened to 740 × 560 to accommodate the split layout

### Multi-Blog Profile Support
- Introduced `BlogProfile` model: each profile stores name, blog root, content path, images path, per-blog subpath templates, and categories
- Settings → General tab replaced with a blog profiles list (add, edit, delete, select active profile)
- Profile editor sheet: Blog Root picker auto-fills content/images paths; subpath templates per blog; manual overrides preserved
- Image URL prefix removed from settings — auto-derived from `blogRoot`/`staticImagesPath` (Hugo `static/` convention)
- Blog picker added to post editor header (visible only when 2+ profiles exist)
- Existing single-blog configuration migrated automatically to a profile named "sosa0sa" on first launch
- Settings export/import updated to multi-blog JSON format (`profiles` array)

### Drag & Drop from Photos.app
- Implemented `NSView`-based drag-and-drop (`DropTargetView`) using `NSDraggingDestination`
- Used `NSFilePromiseReceiver` to handle Photos.app drags (file promises, not plain URLs)
- Used a single serial `OperationQueue` to prevent concurrent `NSPasteboard` access crash
- Supported plain file URL drops from Finder in addition to Photos.app

### Post Editor Split View
- Left pane: plain-text `TextEditor` pre-filled with Hugo frontmatter and image references
- Right pane: photo thumbnail gallery with filenames
- Frontmatter auto-generated on first photo import; title field syncs to `title:` in frontmatter in real time

### Filename with Date Prefix
- Published filename format: `YYYY-MM-DD-slug.md`
- Date derived from first photo's EXIF `DateTimeOriginal`
- Slug auto-generated from the title; editable independently

### Reset Button
- Confirmation dialog before discarding the post
- Staged image files deleted from disk on reset

### Duplicate Photo Prevention
- Photos with the same filename are ignored if dropped a second time

### Import Progress Indicator
- Frosted-glass overlay showing `x / y` with a linear progress bar during photo import

### Subpath Templates
- Configurable date-based subdirectories using tokens `YYYY`, `MM`, `DD`
- Separate templates for Content Posts and Static Images
- Live preview of resolved path shown in Settings

### Settings Redesign
- Replaced `Form` (which adds an unwanted scrollbar) with a plain `VStack`
- Side-by-side layout for Content Posts and Static Images subpath fields
- Done button at the bottom of the window

### Image URL Preview
- Settings shows a live preview of the effective image URL (prefix + resolved subpath)
- Preview updates dynamically as the subpath template changes

### Hugo Frontmatter Improvements
- Added `categories: []` and `tags: []` fields
- Date value quoted: `date: "2026-03-07"`

### Staging Path Display
- Staging folder path shown above the photo gallery
- Arrow button to reveal the folder in Finder

### Image File Permissions Fix
- Copied images now set to `0644` so web servers (nginx, Apache) can serve them
- Previously Photos.app exports had `0600` (owner-only), making them unreadable by nginx

### App Quit on Window Close
- Closing the main window now quits the app, also dismissing the Settings window

### Categories Management
- **Scan Posts**: scans all `.md` files under the Content Posts path and collects every `categories:` value
- Known categories saved in settings and available across launches
- In the editor: chip-based selector to pick from known categories or add new ones inline
- Selected categories written to `categories:` frontmatter in real time

### Settings Export / Import
- **Export Settings…**: saves all settings to a `blogger-settings.json` file
- **Import Settings…**: restores all settings from a previously exported JSON file
- Allows moving configuration to another Mac without manually re-entering paths and categories

### Theme Switcher (System / Light / Dark)
- Settings → Appearance: segmented control to choose System, Light, or Dark
- "System" follows macOS system appearance automatically
- All `Theme` colours are now fully adaptive using `NSColor` dynamic providers —
  warm cream in light mode, dark charcoal in dark mode
- Fixes white-text-on-white-card bug that occurred when system was in dark mode

### Settings Tabbed Layout
- Split the single-pane Settings window into three icon tabs: **General**, **Categories**, **Appearance**
- Matches the macOS Safari / Things-style toolbar tab pattern using `TabView` with `.tabItem { Label(...) }`
- Removed fixed height constraint — each tab sizes to its own content, eliminating clipped sections
- Removed the Done button (standard macOS window close chrome replaces it)
- Export… / Import… buttons moved into the General tab

### Things-Inspired UI Redesign
- Warm cream background (`#F7F5F2`) throughout the app instead of default system grey/white
- `Theme.swift` centralises all design tokens (background, panel, accent, card, chip colours)
- Post editor header: plain-style `TextField` with no border, larger title font, subheadline labels
- Category chips: capsule shape with soft blue fill, replacing plain rounded rectangles
- Photo thumbnails: white card with subtle drop shadow and rounded corners
- Photo gallery panel: warmer panel colour to distinguish from the editor area
- Welcome screen: icon centred in a soft circle, calm dashed drop-zone border
- Footer: cleaner layout with plain Reset button and accent-tinted Publish button

### Documentation
- `README.md`: usage guide, configuration storage details, build instructions, project structure
- `HISTORY.md`: this file

---

## Upcoming

### Tags Support
- Similar to categories: scan existing posts for tags, select/add in the editor
- Tags written to `tags:` frontmatter

### Image Resizing / Optimisation
- Option to resize images before copying to the static directory (e.g. max width 2048px)
- Reduce file size for faster page loads

### Post Preview
- In-app markdown preview rendered as HTML
- Toggle between editor and preview in the left pane

### Multiple Drafts
- Save multiple in-progress posts and switch between them
- Currently only one pending post is held in memory at a time

### Share Extension (Photos.app)
- Trigger the app directly from the Photos.app Share sheet
- Photos exported and app opened automatically via `blogger://new-post` URL scheme
