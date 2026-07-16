# Obsidian Dailies → org-roam Migration

Date: 2026-07-15
Status: approved

## Purpose

One-time migration of the 74 Obsidian daily notes in `~/notes/splash/daily/`
(2024-07-16 through 2026-07-15) into org-roam dailies
(`~/org-roam/daily/YYYY-MM-DD.org`), matching the existing org daily format
(top-level `* Meeting Title -- date` headings, `=(time)=` / `=attendees=`
verbatim lines, subheadings for notes). The Obsidian daily workflow retires
after the migration; the script is read-only on the vault.

Embedded images and file attachments are part of the migration: they are
copied into a single `~/org-roam/attachments/` directory and linked so they
render inline in org. `jcs/org-screenshot` is updated to save new screenshots
into that same directory instead of per-file `<name>_imgs/` directories.

## Decisions made during brainstorming

- Scope is the **daily notes only** — not the `meetings/`, `projects/`, or
  other vault folders, and not the `impact` vault.
- **One-time migration**, not an ongoing sync. Still safely re-runnable via a
  per-file import marker (resume after partial failure, dev iteration).
- Conversion is **pandoc-based** (`gfm` → `org`), with pre/post-processing for
  Obsidian-specific syntax. Chosen over a hand-rolled converter because some
  dailies contain fenced code blocks with `#`-prefixed lines that naive
  line-by-line conversion would corrupt into org headings. pandoc joins the
  Brewfile.
- Attachments live in a **single flat directory** `~/org-roam/attachments/`,
  for both migrated files and future screenshots.
- Wikilinks to other vault notes (`[[Direct Pay Discounts]]`) become plain
  text — their targets are not migrating.
- Only one date collides with an existing org daily (2026-07-15); the user
  confirmed there is no content overlap, so appending is safe.

## Components

### 1. `bin/obsidian-daily-migrate` (bash)

Per file in `$OBSIDIAN_DAILY_DIR` (default `~/notes/splash/daily`), taken in
date order:

1. **Dedupe check** — skip if the target org daily already contains the
   marker comment `# obsidian-import: YYYY-MM-DD.md`.
2. **Preprocess** (before pandoc):
   - `![[name.png]]` (image extensions) → standard markdown image pointing at
     `../attachments/name.png`; copy the file from the vault's `attachments/`
     into `$ORG_ATTACHMENTS_DIR` (default `~/org-roam/attachments/`),
     filename preserved (including spaces).
   - Non-image embeds (`![[PostQual-Debrief (1).xlsx]]`) → regular file link;
     file copied the same way.
   - `[[Note Name]]` → plain text `Note Name`.
   - Referenced attachment missing from the vault → warn, leave the original
     text in place.
3. **Convert** — `pandoc -f gfm -t org --wrap=preserve`. Handles `#` → `*`,
   `` `code` `` → `=code=`, fences → `#+begin_src`, checkbox lists, and
   leaves `#` lines inside code fences alone.
4. **Postprocess** — strip pandoc noise (`:CUSTOM_ID:` drawers, `<<anchor>>`
   targets); ensure image links are `[[file:../attachments/…]]` so org
   renders them inline.
5. **Write** — create the org daily with the same template `daily-note` uses
   (`:PROPERTIES:`/`:ID: <uuidgen>`/`:END:` + `#+title: YYYY-MM-DD`) if
   missing; append the converted content followed by the import marker.

Failure handling: a failing file warns and continues; missing pandoc aborts
upfront with an install hint. Ends with a summary:
`migrated N, skipped M, copied K attachment(s), W warning(s)`.

Env overrides (for tests): `OBSIDIAN_DAILY_DIR`, `DAILY_DIR`,
`ORG_ATTACHMENTS_DIR`.

### 2. `jcs/org-screenshot` tweak (`emacs.d/init.el`)

Save screenshots to `~/org-roam/attachments/<timestamp>_<rand>.png` (single
flat directory, created if missing) instead of a `<buffer-name>_imgs/`
directory per file. Insert the link relative to the buffer's file (e.g.
`[[file:../attachments/…]]` from `daily/`) via `file-relative-name`, then
`org-display-inline-images` as today.

### 3. `Brewfile`

Add `pandoc`.

## Error handling

- Script never writes to the vault; interrupted runs resume via the marker.
- Per-file conversion errors are isolated (warn + continue).
- Attachment copy uses `cp -n`-style semantics: an already-copied file is not
  an error.

## Testing (red/green TDD, bats)

Fixture vault + `DAILY_DIR`/`ORG_ATTACHMENTS_DIR` in temp dirs. Cases:

- Creates the org daily with the ID-drawer + title template.
- Appends to an existing org daily without touching its content.
- Import marker makes a re-run a no-op (`skipped`).
- Image embed → file copied to attachments dir + `[[file:../attachments/…]]`
  link in the org output.
- Non-image embed (xlsx) → file copied + plain file link.
- `[[wikilink]]` → plain text.
- Fenced code block with `#`-prefixed lines survives as `#+begin_src`
  content, not headings.
- Heading levels map `#`→`*` through `####`→`****`.
- Missing attachment → warning, original text preserved, exit 0.
- Summary line counts migrated/skipped/copied/warnings.

`jcs/org-screenshot`: manual verification (take a screenshot from a daily
note buffer; confirm file lands in `~/org-roam/attachments/` and displays
inline).

## Out of scope

- Ongoing Obsidian → org sync.
- Other vault folders (`meetings/`, `projects/`, `People/`, …) and the
  `impact` vault.
- Deleting or archiving the Obsidian sources (manual, after the user verifies
  the migration).
