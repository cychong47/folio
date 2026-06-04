# Folio — Project Instructions for Claude

## After every enhancement or bug-fix
1. Update `HISTORY.md` — add a bullet under `### vX.Y` (the current version) in the `Released` section. Use the format: `- Short description — detail (closes #N)`.
2. Update `README.md` — add a one-line bullet to the **Features** section for every new user-visible feature; update Usage/Configuration if the change affects them.
3. Update `docs/features.md` — add the feature under the appropriate category group. This is the public-facing grouped feature list shown on the GitHub Pages site.
4. Bump `CFBundleShortVersionString` in `project.yml`, run xcodegen, then commit and push all changed files in a single commit. CI will regenerate `docs/index.md` and publish a new GitHub Release automatically.

## HISTORY.md format
Each release is a `### vX.Y` section under `## Released`. Bullets are plain text with enough context to be read standalone:
```
### v1.7
- GitHub Pages release notes site — auto-generated from HISTORY.md on every CI push
- Settings → Updates: Release Notes link
```
Do NOT add free-form sections without a version heading. `docs/index.md` is auto-generated from this format by CI — do not edit it directly.

## Code conventions
- Deployment target: **macOS 13.0** — use `.onChange(of:) { newValue in }` (1-arg), not the 2-arg form.
- No `#Preview` macros (breaks swiftc CLI typecheck).
- All design tokens (colours, spacing) live in `folio/Views/Theme.swift`.
- Run xcodegen with `/tmp/xcodegen_bin/xcodegen/bin/xcodegen generate` (no brew).

## Project structure reminders
- `Shared/Constants.swift` — UserDefaults keys shared between app and extension.
- `HISTORY.md` — version-grouped changelog; CI parses this to generate `docs/index.md`.
- `README.md` — user-facing usage and configuration docs.
- `docs/features.md` — public feature list grouped by category; manually maintained.
- `docs/index.md` — auto-generated release notes page; do not edit directly.
