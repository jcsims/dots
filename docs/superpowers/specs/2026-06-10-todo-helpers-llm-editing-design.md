# Todo helpers: LLM-friendly editing, IDs, and tags

**Date:** 2026-06-10
**Status:** Approved design, pre-implementation

## Problem

The fish todo helpers (`todo`, `doing`, `done`, `next`, `archive`) manage a
personal markdown task list at `~/todo.md` (a symlink to
`~/notes/splash/todo.md`, a separate notes repo). The file has three sections —
`## Doing`, `# Todo`, `## Archive` — where each task is a checkbox line with
optional context lines (URLs, notes) beneath it.

Two gaps block using an LLM session to maintain this list:

1. **No edit operation.** Helpers can add and transition tasks, but not edit a
   task's text or attach context to a *specific* task.
2. **No machine-addressable identity.** Helpers operate positionally ("the top
   backlog task"), which is fragile for an agent that wants to act on a
   particular task across sessions.

A third need surfaced during design: associating a **general context/category**
with a task (a repo name, "admin", etc.) so the user can ask an LLM to "pick up
the next *lender-integration* task."

### Existing latent bug

Context lines are formatted inconsistently: indented in `## Archive`, but
flush-left in `## Doing`/`# Todo`. The helpers only recognize **indented**
context (`^\s+[^-]`), so flush-left context lines are invisible to `next` and
get **orphaned** (left behind) when `doing` promotes a task. `archive`
re-implements the same fragile parse independently and shares the bug.

## Tools evaluated and rejected

- **beads (`bd`)** — dependency-graph issue tracker (JSONL-in-git, hash IDs,
  epics/relations) for multi-agent *software* backlogs. Owns the data model;
  overkill for a single personal markdown file.
- **Backlog.md** — markdown-native but one `.md` file per task with YAML
  frontmatter + kanban/web UI, aimed at human+agent collaboration inside a code
  repo. Also replaces the single-file model.
- **Taskwarrior** — excellent CLI editing but stores in its own opaque DB, not
  markdown.

All three would replace the single hand-readable/hand-editable `todo.md` the
user depends on. The one good idea worth borrowing — **stable task IDs** — is
adopted below without adopting any tool.

## Chosen approach (A): block-aware refactor

Redefine a **task block** as a task line plus every following line until the
next task line or section header — *indentation-independent*. This becomes the
single parsing rule, replacing the scattered `^\s+[^-]` inner loops and fixing
the orphan bug. `archive` is rebuilt on the shared parser instead of its own
copy.

## On-disk format

Headers unchanged (`## Doing`, `# Todo`, `## Archive`). Canonical task line:

```
- [ ] <text> @<tag> (<id>)
  <indented context line>
  <indented context line>
```

- **`(id)`** — 3-character base36 (`a–z0–9`), randomly generated,
  uniqueness-checked against every ID in the file. Always present after the
  first command run.
- **`@tag`** — single, free-form, optional; positioned before `(id)`.
- **Context lines** — always normalized to 2-space indentation on write.

## Parsing model

Line-array partitioning (`_todo_read` → `__td_doing`/`__td_todo`/`__td_archive`)
is retained, but block extraction becomes uniform via shared helpers:

- `_todo_block_bounds <section-array> <start-idx>` — returns the last line index
  of the task block beginning at `start-idx` (next task line / end of section).
- `_todo_find_id <id>` — scans all three sections; returns the section name and
  start index, or fails if not found.
- `_todo_gen_id` — returns a 3-char base36 ID not already present in the file.
- A line parser that splits a task line into checkbox state / text / tag / id
  (for `show`, `edit`, `tag`).

`_todo_read` keeps its current guard: refuse (return 1) on non-blank content
before the first header or on an unexpected header.

## Command surface

`todo` is a dispatcher. Recognized first words are subcommands; **bare `todo`
or an unrecognized first word prints usage** (no implicit add).

| Command | Behavior |
|---|---|
| `todo add <text>` | Add to backlog; assigns an ID; parses a trailing `@tag` if typed |
| `todo edit <id> <text>` | Replace task text; preserves checkbox state, tag, id, and context lines |
| `todo note <id> <text>` | Append an indented context line under the task |
| `todo tag <id> <tag>` | Set/replace the task's `@tag`; `-` clears it |
| `todo show <id>` | Print the full task block (text + tag + id + context) |
| `todo --help` / `-h` | Overview: data model + every verb |
| `doing` | Promote first incomplete backlog task to Doing (unchanged) |
| `doing <text>` | Add interruption task to top of Doing (unchanged; now ID-assigned) |
| `doing <id>` | Promote *that specific* task to Doing (ID lookup takes priority) |
| `done` | Complete first Doing (else top backlog) task (unchanged) |
| `done <id>` | Complete *that specific* task |
| `next [n] [@tag]` | Print Doing + next n backlog tasks; optional `@tag` filter; output includes IDs |
| `archive` | Move `[x]` tasks to Archive (unchanged behavior, rebuilt on shared parser) |

Subcommand reserved words: `add, edit, note, tag, show, --help`, `-h`.

`doing <arg>` disambiguation: if `arg` matches an existing task ID, promote that
task; otherwise treat `arg...` as interruption text.

`next` argument parse: numeric token → count; `@`-prefixed token → tag filter;
order-independent.

## Backfill / migration — automatic on write

No separate migration command. `_todo_write` **guarantees every task has an ID**
(assigning one to any block lacking a trailing `(id)`) and normalizes context
indentation. The first command run therefore backfills all existing tasks and
reformats the file in one canonical rewrite, and the file stays self-healing if
an ID-less task is ever hand-added.

**Manual safety step:** `~/notes/splash/todo.md` lives in an Obsidian vault and
is not version-controlled, so keep a plain file backup (`cp`) before the first
run, since the one-time reformat produces a visible diff.

## Discoverability

- `todo --help` documents the model and every verb; subcommands print brief
  usage on `--help` or misuse. The functions remain the source of truth.
- **Skill** at `config/claude/skills/todo/SKILL.md`, symlinked to
  `~/.claude/skills/todo/SKILL.md` via `bootstrap` (same pattern as the existing
  `jira` skill). It describes the file model (sections, IDs, `@tags`, context
  lines), the verbs, and how to pick up the next task by tag, and points the
  agent at `todo --help` for exact usage.

## Files & wiring

- **New:** `_todo_block_bounds.fish`, `_todo_find_id.fish`, `_todo_gen_id.fish`
  (and a line-parsing helper), `config/claude/skills/todo/SKILL.md`.
- **Modified:** `todo.fish`, `doing.fish`, `done.fish`, `next.fish`,
  `archive.fish`, `_todo_read.fish`, `_todo_write.fish`.
- **`bootstrap`:** add `mkdir -p ~/.claude/skills/todo`; add `maybe-link` lines
  for each new fish helper and the SKILL.md.

## Testing

A fish test script spins up a temp `todo.md` and asserts:

- Backfill + indentation normalization on first write (incl. flush-left context
  becomes indented and is *not* orphaned).
- `add` with and without a trailing `@tag`.
- `edit` preserves state/tag/id/context while replacing text.
- `note` appends indented context to the correct block.
- `tag` sets, replaces, and clears (`-`) a tag.
- `show` prints the full block.
- `doing`/`done` by ID *and* positional (no-arg / free-text) paths.
- `archive` moves completed tasks with their context intact (no orphans).
- `next` tag-filtering and ID-inclusion in output.
- ID-collision avoidance (`_todo_gen_id` skips existing IDs).
- Malformed-file refusal (unexpected pre-header content / header).

Harness location matches repo conventions (verified during planning).
Implementation follows TDD.
