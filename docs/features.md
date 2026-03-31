---
layout: default
title: Features
description: Full feature list for Folio — a native macOS app for creating Hugo blog posts from photos
---

# Features

[← Release Notes](index)

---

## Content Authoring

- **Split-view post editor** — monospaced markdown editor on the left; text + image preview on the right showing content in document order
- **Live text + image preview** — typed text and photos rendered in sequence so you can see how captions relate to photos before publishing
- **Hugo frontmatter auto-generation** — title, date (with time and timezone offset), categories, tags, and series written automatically at Save time
- **Custom frontmatter fields** — define extra key/value pairs per profile (e.g. `author`, `description`, `og_image`) appended to every post's frontmatter
- **Live slug** — filename slug auto-generated from the title and kept in sync as you type; independently editable
- **Title validation** — Save is blocked with a red-bordered title field when the title is empty
- **Editable post date** — date picker in the editor header; defaults to first photo's EXIF date or today; changing it renames staged photos and updates markdown references
- **Series field** — optional series picker below Tags; written as `series: [Name]` in frontmatter

---

## Photos & Image Import

- **Drag & drop from Photos.app** — uses `NSFilePromiseReceiver` to handle Photos.app file promises
- **Drag & drop from Finder** — plain file URL drops also supported
- **EXIF date prefix** — filenames derived from `DateTimeOriginal` (e.g. `2026-03-05-photo.jpg`)
- **Non-EXIF date fallback** — screenshots and downloaded images get their date from `PHAsset.creationDate` (Photos access required), file creation date, or today
- **Sort by filename** — photos dropped in the same session are sorted by filename ascending, preserving capture sequence
- **Duplicate photo prevention** — the same filename dropped twice is silently ignored
- **Import progress overlay** — frosted-glass overlay with `x / y` counter and progress bar during photo import

---

## Image Export

- **Image resize cap** — set a max long-edge dimension per profile; images exceeding the limit are downscaled while preserving aspect ratio
- **EXIF metadata stripping** — GPS coordinates and device info removed from images on export (on by default); preserves `DateTimeOriginal` for filename generation only
- **Image file permissions** — exported images set to `0644` so web servers (nginx, Apache) can serve them
- **Subpath templates** — configurable date-based subdirectories using `YYYY`, `MM`, `DD` tokens; separate templates for content posts and static images

---

## Categories & Taxonomy

- **Chip-based category editor** — pick from known categories or type a new one inline; written to `categories:` frontmatter in real time
- **Tags field** — same chip UI as categories; written to `tags:` frontmatter
- **Scan Posts** — scans all `.md` files in the content directory and collects every `categories:` and `series:` value
- **Auto-scan** — background scan every 30 minutes while the app is running; toggle per profile in Settings

---

## Publishing

- **Save to local Hugo repo** — writes `YYYY-MM-DD-slug.md` and copies images to the configured static directory
- **GitHub publish** — commits and pushes only the saved files via the GitHub REST API (no git binary required)
- **Codeberg & Gitea support** — full URL accepted in the Repo field; API base auto-derived from the host
- **Auto-detect GitHub settings** — reads repo and branch from the blog root's `.git/config`
- **Delete local files after publish** — markdown and image files removed from the local Hugo repo automatically after a successful GitHub push

---

## Settings & Profiles

- **Multi-blog profiles** — each profile stores name, blog root, content path, images path, subpath templates, categories, GitHub settings, image export settings, and custom frontmatter fields
- **Settings export / import** — transfer all profiles to another Mac via a JSON file
- **Image URL prefix** — auto-derived from blog root and static images path; no manual configuration needed
- **Live path preview** — shows the resolved content and image paths as subpath templates change

---

## App & Distribution

- **OTA updates** — Settings → Updates checks GitHub Releases; one-click download and install via Archive Utility
- **Release Notes** — Settings → Updates links to the release notes page
- **Share Extension** — trigger the app from the Photos.app Share sheet; photos exported and app opened automatically
- **Theme switcher** — System / Light / Dark; fully adaptive warm-cream / dark-charcoal palette
- **Quit on window close** — closing the main window also dismisses Settings and quits the app
