# Photolog Editor and Blog Management Roadmap

This note summarizes product ideas inspired by
<https://blog.outsider.ne.kr/1798/> and adapts them to Photolog's current
direction.

The referenced app is useful as a comparison because it treats blog writing as a
complete workflow: draft persistence, markdown editing, preview, writing
statistics, revision support, link assistance, and metadata management. For
Photolog, the highest-value direction is not to replace the user's writing with
AI, but to reduce fragile repeated work around photo-backed posts and existing
post maintenance.

## Product Direction

Photolog should grow from a photo-to-post tool into a lightweight blog
management workspace.

The current strength is creating a new post from selected photos, especially via
curation. The next step is to make the app reliable for longer editing sessions
and repeated blog maintenance:

- Preserve work automatically, including selected photos and curation context.
- Improve the editor for both new posts and existing posts.
- Make existing post browsing and editing feel like a first-class workflow.
- Add assistive review tools that keep the user in control.

The user's current blog theme does not support image previews or cover images.
Because of that, cover image and representative image workflows should be
deprioritized even though they are common in other blogging tools.

## Priority 1: Existing Post Management

The app should continue expanding beyond "create a new photo post" into
"manage the blog's existing posts".

Photolog already has a Browse Posts path, but this area should become more
capable over time. Existing post editing is where markdown support, statistics,
revision suggestions, and link tools become broadly useful, not only photo-post
specific.

Recommended direction:

- Keep Browse Posts as a persistent workspace when editing an existing post.
- Preserve browse filters, selected row, and scroll position after editing.
- Clearly separate "editing an existing post" from "creating a new post".
- Support drafts for existing posts so unsaved changes survive app restarts.
- Make frontmatter visible and editable without requiring manual raw edits for
  common fields.

This aligns Photolog with the referenced editor's broader workflow: the app is
not only a post generator, but a place to maintain the blog.

## Priority 2: Stronger Markdown Editing Support

Markdown editing should be improved before adding heavier AI features.

The goal is not to hide markdown. The goal is to remove repetitive syntax work
and make photo-heavy posts easier to edit accurately.

Candidate features:

- Toolbar actions for common markdown operations: heading, bold, italic, link,
  quote, code, code block, bullet list, numbered list, and horizontal rule.
- Link insertion for selected text.
- Image insertion at cursor using already staged photos.
- Jump from preview image to its markdown source line.
- Show helper-only photo filenames in preview, without writing filenames into
  the saved post content.
- Fold or visually separate frontmatter from the body.
- Detect broken image references, missing staged files, and markdown paths that
  no longer match exported files.

These features should apply equally to new posts, curation-created posts, and
existing posts opened from Browse Posts.

## Priority 3: Writing Statistics Panel

A compact statistics panel would make the editor more useful for existing post
maintenance.

Recommended metrics:

- Character count.
- Word count.
- Paragraph and heading count.
- Estimated reading time.
- Photo count.
- Total referenced image count.
- Missing alt text count.
- Broken local image reference count.

The panel should be passive and compact. It should not interrupt writing or
force quality rules. Its value is quick visibility before saving.

For Korean posts, reading-time calculation should use a Korean-friendly heuristic
instead of assuming English word boundaries are always meaningful.

## Priority 4: Revise Sidebar

Status: local deterministic MVP implemented in v1.21.52. Remaining work should
focus on richer navigation, ignore controls, and optional external/AI-assisted
review after the basic editor flow is stable.

A Revise sidebar should provide suggestions without rewriting the post
automatically.

Useful checks:

- Typos and suspicious spacing.
- Repeated words or repeated sentences.
- Very long sentences.
- Awkward wording suggestions.
- Missing alt text for images.
- Broken links or malformed markdown links.
- Frontmatter issues such as missing title, missing date, or invalid taxonomy.

Interaction model:

- Suggestions appear in a sidebar grouped by severity or type.
- Selecting a suggestion jumps to the relevant editor location.
- The user chooses whether to apply, ignore, or manually edit.
- AI-generated suggestions should always be presented as suggestions, not
  automatic edits.

This is especially useful for editing existing posts, where the app can help
review older content without changing it unexpectedly.

## Priority 5: Link Assistance

Link assistance can become valuable once Browse Posts is treated as a blog
library.

Candidate features:

- Suggest links to existing posts when selected text matches an existing title,
  slug, tag, or frequently used phrase.
- Show previous URLs used for the same text.
- Detect broken external links.
- Open links from the editor or preview quickly.
- Suggest internal links from related posts, tags, or series.

This should come after the editor and Browse Posts model are stable, because the
feature depends on reliable indexing of existing content.

## Lower Priority: Cover Image and Representative Image

Cover image workflows should be lower priority for now.

The current blog theme does not support image previews or cover images, so
choosing a representative photo would not create immediate user-visible value.
This can be revisited later if the blog theme changes or if Photolog starts
supporting multiple theme profiles with cover-image metadata.

Possible future use:

- Optional frontmatter field for themes that support cover images.
- OpenGraph image support if the site later adopts it.
- Thumbnail selection for an internal Photolog post browser, independent of the
  published theme.

Until then, effort should go to editor reliability, markdown assistance,
statistics, and revision workflows.

## Suggested Implementation Order

1. Existing post draft support for Browse Posts editing.
2. Markdown toolbar and editor helpers.
3. Editor/preview image-source navigation and filename helpers.
4. Writing statistics panel.
5. Revise sidebar with local deterministic checks first.
6. Optional AI suggestions for revise and alt text after the non-AI workflow is
   reliable.
7. Link assistance backed by the existing post index.
8. Cover image or OpenGraph image support only if the blog theme begins using
    those fields.

## Non-Goals for the Near Term

- Fully WYSIWYG editing.
- AI-generated full posts.
- Theme-specific cover image workflows.
- Automatic publishing decisions.
- Rewriting user text without explicit confirmation.

## Remaining Success Criteria

The remaining roadmap is working if:

- A user can edit an existing post without losing Browse Posts context.
- The editor makes markdown operations faster without hiding the source.
- The app surfaces useful writing and post-health information before save.
- Suggestions remain reviewable and reversible.
