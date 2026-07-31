# Obsidian inline TODOs → Things tracking tasks

Date: 2026-07-22
Status: approved

## Purpose

Let me jot inline TODOs while taking notes anywhere in the Obsidian vault
(`~/notes/splash/`), then run a helper that turns each unchecked TODO into a
tracked Things task and writes a clickable Things link back onto the Obsidian
line. A second pass syncs completion the other way: when a linked Things task is
done, its Obsidian checkbox is ticked.

This is the inverse of the retired `things-to-daily` flow: Obsidian owns
note-taking and TODO capture; Things owns task tracking.

## Decisions made during brainstorming

- **Marker: none — every unchecked `- [ ]` checkbox in the vault is pushed.**
  No tag is required. The vault currently has zero unchecked checkboxes, so
  turning the whole vault into push candidates is safe today; the injected
  Things link is still the dedupe marker, so a line is only ever pushed once.
  (This supersedes an earlier, since-abandoned design that required a
  standalone `#things` tag to opt a line in.)
- **Scope: the whole vault** (`~/notes/splash/**/*.md`), skipping `archive/`
  and `templates/`. Because every unchecked checkbox is a candidate, this
  means every unchecked box in the vault becomes a Things task.
- **Destination: the Work area, tagged `@work`** — mirrors the
  `THINGS_AREA`/`THINGS_TAG` convention from `things-to-daily`. The Things task
  notes get an `obsidian://` backlink to the source note.
- **Two-way**, in two explicit passes: `push` (Obsidian → Things create + link)
  and `sync` (Things → Obsidian tick the box when the task is completed).
- **The injected Things link is the dedupe marker.** A line that already
  contains `things:///show?id=` is never pushed again. On push, the id link is
  appended to the line, so the line reads cleanly and cannot re-match. (A
  query-link fallback, used when UUID recovery is ambiguous, has no uuid to
  dedupe on — see the `push` pass below.)

## Key CLI finding (why UUID recovery is indirect)

`things add` creates the task and exits 0 but prints **nothing** — no UUID, even
with `-j`. `things import` (JSON URL scheme) likewise returns `[]`. So the new
task's UUID is recovered by **diffing the Work area's task list before and after
each create**: capture the sorted UUID set from `things list anytime --area
Work -j`, create one task, capture again, and the single new UUID is the
difference. Verified end-to-end (create → recover → cancel).

`things show <uuid> -j` reports `.status` (`open` / `completed` / `canceled`),
which drives the sync pass. Verified against the same stub contract
`things-to-daily` relies on.

## Components

### `bin/obsidian-todo-to-things` (bash)

Subcommands:

- `obsidian-todo-to-things push` — scan, create, link back.
- `obsidian-todo-to-things sync` — tick boxes for completed linked tasks.
- `obsidian-todo-to-things` (no arg) — run `push` then `sync`.

Preflight: require `things`, `jq`, `find`; abort with an install hint if any is
missing (matches `things-to-daily`).

#### `push` pass

Walk every `*.md` under `$OBSIDIAN_VAULT_DIR` except the `archive/` and
`templates/` subtrees, in a stable (sorted) order. For each file, rewrite it via
a temp file and `mv` **only if it changed**. A line is a **push candidate** when
it matches `^(\s*)- \[ \] (.*)$` and does **not** already contain
`things:///show?id=`. That's the whole rule — no tag is required, so every
unchecked checkbox not yet linked is a candidate.

For each candidate, in file order:

1. **Title** = the task text, trimmed of leading/trailing whitespace, used
   verbatim. Any `#tags` (including a literal `#things`, if present from the
   old workflow) and any URLs stay in the title text untouched — nothing is
   stripped.
2. **Notes body** = an `obsidian://` backlink line, then any **continuation
   lines**: the immediately-following lines that are non-blank and indented
   *deeper* than the task marker and are **not** themselves task lines
   (`- [ ]` / `- [x]`). Consumption stops at the first blank line, a line
   indented at or below the task, or a nested task line. Continuation lines are
   left untouched in the note; they are only *copied* (dedented) into the Things
   notes.
   - Backlink: `obsidian://open?vault=$OBSIDIAN_VAULT&file=<uri>` where `<uri>`
     is the vault-relative path with `.md` stripped, URL-encoded via
     `jq -rn --arg s "$rel" '$s|@uri'`.
3. **Create**: capture the before-set (`things list anytime --area
   "$THINGS_AREA" -j | jq -r '.[].uuid' | sort`), run
   `things add "$title" --list "$THINGS_AREA" --tags "$THINGS_TAG" --notes
   "$notes"`, capture the after-set, and diff with `comm -13`.
4. **Link back**:
   - Exactly one new UUID → rewrite the line as
     `<indent>- [ ] <title> [⤴](things:///show?id=<uuid>)`.
   - Zero or more-than-one new UUID → **warn**, and fall back to a query link
     `[⤴](things:///show?query=<uri-encoded title>)` so the line is still
     clickable. These fall-back lines have no uuid, so they cannot participate
     in `sync`, and — since the candidate check only excludes lines already
     containing `things:///show?id=` — a fall-back line remains a push
     candidate and is pushed again on the next run. The warning notes this.

Summary: `pushed N todo(s), skipped M already-linked, W warning(s)`.
("skipped" counts candidates that already carried a `things:///show?id=` link.)

#### `sync` pass

Walk the same files. For every line matching `^(\s*)- \[ \] (.*)$` that contains
`things:///show?id=<uuid>`, run `things show <uuid> -j`:

- `.status == "completed"` → flip the checkbox to `- [x]` (everything else on
  the line, including the link, preserved). Count it.
- `.status == "open"` → leave it.
- `.status == "canceled"` → leave it (the TODO was abandoned, not done).
- task not found / empty status → **warn**, leave it.

Rewrite each file via temp file + `mv` only if it changed.

Summary: `completed K todo(s) from Things, W warning(s)`.

### Env overrides (also the test seams)

- `OBSIDIAN_VAULT_DIR` — vault root (default `~/notes/splash`).
- `OBSIDIAN_VAULT` — vault name for the `obsidian://` link (default `splash`).
- `THINGS_AREA` — destination area / `--list` value (default `Work`).
- `THINGS_TAG` — tag applied to created tasks (default `@work`).

## Error handling

- Missing dependency → abort upfront with an install hint.
- A file that fails to process warns and continues; the pass still exits 0 and
  prints its summary.
- Never edits a file whose content is unchanged (idempotent re-runs).
- UUID-diff ambiguity is handled by the query-link fallback + warning, so a
  create is never silently dropped. Because the query-link fallback carries no
  uuid, it does not satisfy the `things:///show?id=` dedupe check, so an
  ambiguous line remains a push candidate and creates another Things task on
  each subsequent run until an id link is recovered.

## Testing (red/green TDD, bats)

`test/obsidian-todo-to-things.bats`, mirroring `things-to-daily.bats`. A
`things` stub backed by a JSON task store in `$BATS_TEST_TMPDIR`:

- `add …` appends a task with a deterministic UUID (incrementing counter) to the
  store, honoring `--tags`/`--notes`/`--list`.
- `list anytime --area Work -j` prints the store as JSON (drives the diff).
- `show <uuid> -j` prints `{"uuid","status"}` from the store; a test helper
  marks a stored task `completed` to exercise `sync`.
- `cancel` / unexpected calls behave like the `things-to-daily` stub.

Fixture vault under `$OBSIDIAN_VAULT_DIR` with `archive/` and `templates/`
subdirs. Cases:

- **push**
  - Unchecked `- [ ]` line with no tag → task created in Work with `@work`;
    line rewritten with the `things:///show?id=` link; task title matches the
    trimmed line text verbatim.
  - A hashtag in the checkbox text (e.g. `#reng`) is preserved verbatim in the
    pushed title — nothing is stripped.
  - A checked `- [x]` line is never a candidate and is left untouched.
  - Continuation lines (deeper-indented non-task lines) → copied into the task
    notes, dedented; a nested `- [ ]` subtask line stops consumption (it is not
    copied into the parent's notes) but is itself pushed as its own candidate,
    since every unchecked checkbox is a candidate.
  - `obsidian://` backlink present in notes with the correct URL-encoded
    relative path and vault name.
  - Files under `archive/` and `templates/` are skipped.
  - Re-run is a no-op for an already id-linked line: counted as skipped, no
    new task.
  - Summary line counts pushed/skipped/warnings.
  - Ambiguous/zero diff → warning + query-link fallback. Because the fallback
    has no uuid, the line remains a push candidate and is pushed again on the
    next run (see Error handling).
- **sync**
  - Linked line whose task is `completed` → flipped to `- [x]`, link preserved.
  - Linked line whose task is `open` → unchanged.
  - `canceled` → unchanged.
  - Unknown UUID → warning, unchanged.
  - Summary line counts completed/warnings.
- **no-arg** runs push then sync (both summaries printed).

## Out of scope

- Translating other Obsidian `#tags` into Things tags.
- Syncing edits to task *titles* or notes after creation (create-once).
- Reflecting Things *cancellation* into Obsidian.
- Any project/heading placement inside Things beyond the Work area.
