# Blogger — Change History

---

## Released

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
