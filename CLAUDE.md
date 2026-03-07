# Blogger — Project Instructions for Claude

## After every enhancement or bug-fix
1. Update `HISTORY.md` — add a bullet under the appropriate section (`Released` for shipped work, `Upcoming` for planned features). Remove items from `Upcoming` once they are implemented.
2. Update `README.md`:
   - Add a one-line bullet to the **Features** section for every new user-visible feature.
   - Update the Usage / Configuration / Building sections if the change affects them.
3. Commit and push all changed files including the docs in the same commit.

## Code conventions
- Deployment target: **macOS 13.0** — use `.onChange(of:) { newValue in }` (1-arg), not the 2-arg form.
- No `#Preview` macros (breaks swiftc CLI typecheck).
- All design tokens (colours, spacing) live in `blogger/Views/Theme.swift`.
- Run xcodegen with `/tmp/xcodegen_bin/xcodegen/bin/xcodegen generate` (no brew).

## Project structure reminders
- `Shared/Constants.swift` — UserDefaults keys shared between app and extension.
- `HISTORY.md` — human-readable changelog; keep it up to date.
- `README.md` — user-facing usage and configuration docs.
