# Daily Context → org-roam Dailies

Date: 2026-07-13
Status: approved

## Purpose

Bring daily work context into org-roam daily notes (`~/org-roam/daily/YYYY-MM-DD.org`)
on demand, from four sources:

1. **Things 3** — work-tagged tasks, one-way captured into org (quick/phone capture
   funnels into org; org becomes the source of truth).
2. **Slack** — threads I posted in, messages I saved for later, and @mentions of me,
   each as a permalink plus a short factual summary.
3. **Jira / Confluence / Google Docs** — a "what I touched today" activity log with
   links.
4. This also revives org-roam in the Emacs config (removed in commit `09aecd1`),
   replacing the plain `~/org` workflow, which is no longer in use.

Everything is on-demand — no launchd/background jobs.

## Decisions made during brainstorming

- Target is org-roam dailies; the org-roam Emacs config is restored as part of this
  project.
- Things flow is **one-way capture**: once a task lands in org, it is completed in
  Things so it is never imported twice.
- Trigger is **on-demand only** (terminal command, Emacs binding, or `/daily-context`
  in Claude Code).
- Slack captures threads + saved-for-later + mentions with short *factual*
  summaries — no editorializing, no auto-created TODOs.
- Jira/Confluence/Google Docs capture "my activity today" (created/commented/
  transitioned/edited), links + one-line context.
- Architecture is **hybrid**: a standalone local script for Things (runnable from
  Emacs without Claude) and a Claude Code skill for the cloud services, which uses
  the already-authenticated claude.ai MCP connectors (Slack, Atlassian, Google
  Drive) — no credential management.
- `/daily-context` is cloud-only; it does NOT run the Things import. The two entry
  points are fully independent.
- Per-section entry cap is 50.
- The skill delegates each vertical to a lower-power-model subagent (Haiku/
  Sonnet); the frontier model only orchestrates.
- The `~/org` file plumbing (file vars, `jcs/open-*` commands/bindings, refile
  targets, static agenda files) is removed; the recently updated `org-tag-alist`
  is kept.

## Components

All live in the dots repo, following existing patterns (`bin/` scripts,
`config/claude/skills/` symlinked by `bootstrap`).

### 1. `bin/daily-note` — shared org writer (bash)

The single place that knows org formatting and idempotency. Both other components
write through it; nothing else edits daily files programmatically.

CLI:

```
daily-note path
    Print today's note path, creating the file if needed.

daily-note append --section SECTION --key KEY --heading "TEXT" [body on stdin]
    - Creates today's file if missing
    - Creates "* SECTION" if missing (appended at end of file)
    - Appends "** TEXT" plus optional body at the end of that section
      (i.e., before the next top-level heading)
    - If KEY already appears anywhere in the file: does nothing,
      prints "skipped: KEY", exits 0
```

File creation template (org-roam v2 compatible):

```
:PROPERTIES:
:ID:       <uuidgen>
:END:
#+title: YYYY-MM-DD
```

Dedupe rule: plain substring search for KEY in the file. Callers must include the
key in the entry content — naturally true for links (Slack permalink, Jira URL,
doc URL); the Things script passes a `:THINGS_ID:` property drawer in the body.

The daily directory is `~/org-roam/daily`, overridable via a `DAILY_DIR`
environment variable (used by tests).

### 2. `bin/things-to-daily` — Things vertical (bash, no Claude)

Flow:

1. Gather open tasks tagged `@work` (tag name in a variable at the top of the
   script, overridable via env) across views: inbox, today, upcoming, anytime,
   someday — via `things list <view> --tag @work --json`, deduped by task UUID
   across views.
2. For each task, append via `daily-note`:
   - section: `Tasks`
   - key: task UUID
   - heading: `TODO <title>`
   - body:
     - `DEADLINE:` / `SCHEDULED:` lines when the Things task has a deadline /
       scheduled date
     - `:PROPERTIES:` drawer containing `:THINGS_ID: <uuid>`
     - task notes, if any
3. After a successful append (or a dedupe skip), run `things complete <uuid>`.

Failure handling: append first, then complete. If `complete` fails the task stays
in Things, but the `:THINGS_ID:` dedupe key prevents a duplicate on the next run;
the script warns and continues. Exits with a summary (`imported N task(s)`).

Scope (v1): title, notes, and dates only; checklist items are not imported.

### 3. `config/claude/skills/daily-context/SKILL.md` — Claude Code skill

Symlinked to `~/.claude/skills/daily-context/SKILL.md` by `bootstrap` (same
pattern as the jira skill). Invoked as `/daily-context`. Cloud sources only.

Procedure (all scoped to today, local time):

- **Slack** (Slack connector):
  - Threads I posted in: search `from:@me` today; read each thread; write a
    1-line factual summary.
  - @mentions of me today, excluding threads already captured.
  - Saved for later: attempt an `is:saved` search; if the connector cannot
    access saved items, degrade gracefully and say so in the run summary.
  - Entry: heading `[[permalink][#channel: topic]]`, body 1-2 line factual
    summary. Key = permalink. Section = `Slack`.
- **Jira** (Atlassian connector):
  - JQL for issues updated today where I'm assignee/reporter/commenter, plus
    issues I created or transitioned today.
  - Entry: `[[browse-url][KEY: summary]] — <what I did>`. Key = issue key.
    Section = `Jira`.
- **Confluence** (Atlassian connector):
  - CQL for pages I contributed to today.
  - Entry: page link + edited/commented. Key = page URL. Section = `Confluence`.
- **Google Docs** (Drive connector):
  - Docs modified by me today; comment activity if the connector exposes it,
    else degrade gracefully.
  - Entry: doc link + one-line context. Key = doc URL. Section = `Docs`.

Delegation:

- The skill instructs the top-level session to dispatch each vertical (Slack,
  Jira, Confluence, Docs) as a parallel subagent (Agent tool) running a
  lower-power model (Haiku by default; Sonnet if a vertical needs judgment,
  e.g. Slack thread summaries). Gathering via MCP and emitting templated
  `daily-note` calls doesn't need a frontier model.
- Each subagent does its whole vertical — query MCP, format entries, run
  `daily-note append` — and returns a short report (added/skipped/degraded).
  The deterministic helper makes delegated writes safe.
- The top-level session only orchestrates and merges the per-vertical reports
  into the run summary.

Rules:

- Every entry is written via `daily-note append` (Bash tool). The skill never
  edits org files directly.
- Cap of 50 entries per section; skip bot noise.
- Summaries are short and factual — no editorializing, no suggested TODOs.
- The run ends with a summary: what was added per section, what was skipped as
  a duplicate, and any verticals that degraded (e.g., saved-for-later
  unavailable).

### 4. Emacs config revival (`emacs.d/init.el`, `bootstrap`)

Restore (from the pre-`09aecd1` config, adapted):

- `use-package org-roam`: `org-roam-directory` `~/org-roam`, bindings
  `C-c o {l,f,i,c,r}` plus dailies `C-c o {d,p,n,j}`,
  `org-roam-db-autosync-mode`.
- `vulpea` package and the project-tag machinery: `vulpea-project-p`,
  `vulpea-project-update-tag` on `find-file`/`before-save` (adds/removes the
  `:project:` filetag based on open TODOs), `org-roam-buffer-p`, and
  `project` in `org-tags-exclude-from-inheritance`.
- Dynamic agenda: `vulpea-project-files` + `vulpea-agenda-files-update` advice
  on `org-agenda`/`org-todo-list`; `vulpea-agenda-category` prefix format.
  Agenda files = project-tagged roam files + Journelly.

Remove (no longer used):

- `jcs/inbox-file` / `jcs/meetings-file` / `jcs/notes-file` / `jcs/work-file`
  vars, the `jcs/open-*` commands and their `C-c e {i,m,n}` bindings, the
  `org-refile-targets` customization pointing at those files, and the static
  `org-agenda-files` list.

Keep:

- The current `org-tag-alist` (recently updated) and all other org settings.

New:

- `jcs/things-to-daily`: interactive command that runs `bin/things-to-daily`,
  then opens today's daily note via org-roam (reverting the buffer if already
  open, since the file changed on disk). Bound to `C-c o t`.

## Data flow

```
Things 3 --things CLI--> things-to-daily --\
                                            +--> daily-note --> ~/org-roam/daily/YYYY-MM-DD.org
Slack/Jira/Confluence/GDocs --MCP--> /daily-context --/                 |
                                                        (git-synced by existing sync-org)
```

The existing `~/org-roam/sync` + `bin/sync-org` git sync is unchanged and picks
up daily-note changes on its normal cadence.

## Error handling

- `daily-note`: refuses malformed invocations (missing section/key/heading);
  never partially writes (build entry, single append).
- `things-to-daily`: network-free; tolerates individual task failures and
  continues; complete-failure leaves dedupe protection in place.
- `/daily-context`: each vertical degrades independently — a failing or
  unauthenticated connector is reported in the run summary and skipped, never
  aborting the whole run.
- Concurrent Emacs edits: writers append via the filesystem; the Emacs command
  reverts the daily buffer after import. (auto-revert remains a user option.)

## Testing (red/green TDD)

- `bin/daily-note`: bats-core tests (bats added to `Brewfile`), `DAILY_DIR`
  pointed at a temp dir. Cases: file creation format (ID drawer + title),
  section creation, append position within an existing section, dedupe skip,
  body-from-stdin, `path` subcommand.
- `bin/things-to-daily`: bats tests with a stub `things` executable on PATH
  returning canned JSON. Cases: import happy path (daily-note called with
  right args, complete called), dates mapped to DEADLINE/SCHEDULED, notes in
  body, complete-failure warns but continues, cross-view UUID dedupe.
- `/daily-context` skill: manual verification checklist kept in the skill
  directory (run it, inspect the note, re-run to confirm idempotency, verify
  degradation messaging).

## Out of scope (v1)

- Background/scheduled runs (design keeps them possible later; `daily-note` is
  trigger-agnostic).
- Two-way sync with Things; checklist import.
- Long-form thread digests or auto-created TODOs from Slack/Jira (entries stay
  at link + 1-2 factual lines).
- Migrating historical `~/org` content into org-roam (manual, gradual).
