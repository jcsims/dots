# Daily Context → org-roam Dailies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On-demand tooling that pulls Things 3 work tasks, Slack activity, and Jira/Confluence/Google Docs activity into org-roam daily notes, plus revival of the org-roam Emacs config.

**Architecture:** A shared bash writer (`bin/daily-note`) owns all org formatting and dedupe. A standalone bash script (`bin/things-to-daily`) handles Things one-way capture locally. A Claude Code skill (`/daily-context`) fans the four cloud verticals out to lower-power-model subagents that write through `daily-note`. The Emacs config restores the org-roam + vulpea setup removed in commit `09aecd1`.

**Tech Stack:** bash, jq, `things` CLI, bats-core (tests), Emacs Lisp (org-roam, vulpea), Claude Code skill + MCP connectors (Slack, Atlassian, Google Drive).

**Spec:** `docs/superpowers/specs/2026-07-13-daily-context-org-roam-design.md`

## Global Constraints

- Repo: `/Users/csims/.dots` (bash scripts in `bin/`, fish `bootstrap` does symlinks, `config/claude/skills/` for skills).
- Platform: macOS (BSD userland; `uuidgen` at `/usr/bin/uuidgen`, `date +%F` works).
- Bash scripts start with `#!/usr/bin/env bash` and `set -euo pipefail` (matches `~/org-roam/sync` style).
- Daily notes live at `~/org-roam/daily/YYYY-MM-DD.org`; override dir via `DAILY_DIR` env var (tests depend on this).
- Things tag: `@work`, override via `THINGS_TAG` env var.
- Daily-note sections are exactly: `Tasks`, `Slack`, `Jira`, `Confluence`, `Docs`.
- Per-section entry cap in the skill: 50.
- Dedupe: plain substring search of the key in the day's file; the key must appear in each written entry.
- No background/scheduled jobs — everything is on-demand.
- The git repo has unrelated in-flight changes (`bin/sync-org`, `bootstrap` staged, `config/claude/settings.json`, `launchd/`); commit ONLY the files each task names. Never `git add -A`.
- Commit messages: plain descriptive sentences (repo style, no conventional-commit prefixes).

---

### Task 1: `daily-note path` + test harness

**Files:**
- Create: `bin/daily-note`
- Create: `test/daily-note.bats`
- Modify: `Brewfile` (add bats-core after the `brew 'bat'` line)
- Modify: `Brewfile-work` (same addition)

**Interfaces:**
- Produces: `daily-note path` — prints today's note path (`$DAILY_DIR/YYYY-MM-DD.org`), creating the file with an org-roam header if missing. `DAILY_DIR` defaults to `$HOME/org-roam/daily`.
- Produces (for later tasks): the file header format —
  ```
  :PROPERTIES:
  :ID:       <uppercase-UUID>
  :END:
  #+title: YYYY-MM-DD
  ```

- [ ] **Step 1: Install bats and add it to the Brewfiles**

Run: `brew install bats-core`

In `Brewfile`, after the line `brew 'bat'`, add:

```ruby
brew 'bats-core'
```

In `Brewfile-work`, find the alphabetical position near `brew 'bat'` (if present; otherwise near the top of the plain `brew` entries) and add the same line.

Verify: `bats --version` prints something like `Bats 1.x.x`.

- [ ] **Step 2: Write the failing tests**

Create `test/daily-note.bats`:

```bash
#!/usr/bin/env bats

setup() {
    export DAILY_DIR="$BATS_TEST_TMPDIR/daily"
    PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
    TODAY=$(date +%F)
    NOTE="$DAILY_DIR/$TODAY.org"
}

@test "path prints today's path and creates the file with an org-roam header" {
    run daily-note path
    [ "$status" -eq 0 ]
    [ "$output" = "$NOTE" ]
    [ -f "$NOTE" ]

    mapfile -t lines <"$NOTE"
    [ "${lines[0]}" = ":PROPERTIES:" ]
    [[ "${lines[1]}" =~ ^:ID:\ +[0-9A-Fa-f-]+$ ]]
    [ "${lines[2]}" = ":END:" ]
    [ "${lines[3]}" = "#+title: $TODAY" ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "path is idempotent (does not regenerate the ID)" {
    daily-note path
    id1=$(sed -n 2p "$NOTE")
    daily-note path
    id2=$(sed -n 2p "$NOTE")
    [ "$id1" = "$id2" ]
}

@test "no arguments prints usage and exits non-zero" {
    run daily-note
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}
```

Note: `mapfile` requires bash 4+; bats runs tests with the `bash` found on PATH, which is homebrew bash 5 on this machine. If `mapfile` is unavailable, use `IFS=$'\n' read -d '' -ra lines <"$NOTE" || true` instead.

- [ ] **Step 3: Run tests to verify they fail**

Run: `bats test/daily-note.bats`
Expected: 3 failures (`daily-note: command not found` or exec format errors).

- [ ] **Step 4: Write the implementation**

Create `bin/daily-note` (mode 755):

```bash
#!/usr/bin/env bash
set -euo pipefail

DAILY_DIR="${DAILY_DIR:-$HOME/org-roam/daily}"

usage() {
    cat >&2 <<'EOF'
Usage:
  daily-note path
      Print today's note path, creating the file if needed.
  daily-note append --section SECTION --key KEY --heading HEADING
      Append "** HEADING" (plus body from stdin, if any) under "* SECTION"
      in today's note. If KEY already appears in the file, do nothing.
EOF
    exit 2
}

today_file() {
    echo "$DAILY_DIR/$(date +%F).org"
}

ensure_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        mkdir -p "$DAILY_DIR"
        printf ':PROPERTIES:\n:ID:       %s\n:END:\n#+title: %s\n' \
               "$(uuidgen)" "$(date +%F)" >"$file"
    fi
}

cmd_path() {
    local file
    file=$(today_file)
    ensure_file "$file"
    echo "$file"
}

case "${1:-}" in
    path) cmd_path ;;
    *) usage ;;
esac
```

Run: `chmod +x bin/daily-note`

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats test/daily-note.bats`
Expected: `3 tests, 0 failures`

- [ ] **Step 6: Commit**

```bash
git add bin/daily-note test/daily-note.bats Brewfile Brewfile-work
git commit -m "Add daily-note helper with path subcommand and bats harness"
```

---

### Task 2: `daily-note append`

**Files:**
- Modify: `bin/daily-note`
- Modify: `test/daily-note.bats`
- Modify: `bootstrap` (add symlink line)

**Interfaces:**
- Consumes: Task 1's `ensure_file`/`today_file` helpers and header format.
- Produces: `daily-note append --section SECTION --key KEY --heading HEADING` with optional body on stdin.
  - Creates today's file and/or `* SECTION` if missing.
  - Appends `** HEADING` + body lines at the END of that section (i.e., immediately before the next `* ` top-level heading, or at EOF).
  - Dedupe: if KEY appears anywhere in the file → prints `skipped: KEY`, exit 0.
  - Success prints `added: KEY`, exit 0.
  - Callers with no body MUST redirect stdin from /dev/null (`</dev/null`); the script reads stdin whenever it is not a TTY.

- [ ] **Step 1: Write the failing tests**

Append to `test/daily-note.bats`:

```bash
@test "append creates the section and entry" {
    run bash -c "daily-note append --section Tasks --key K1 --heading 'TODO Buy milk' </dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "added: K1" ]

    expected="* Tasks
** TODO Buy milk"
    [ "$(tail -n 2 "$NOTE")" = "$expected" ]
}

@test "append includes body from stdin" {
    printf 'line one\nline two\n' |
        daily-note append --section Tasks --key K1 --heading 'TODO Buy milk'

    expected="* Tasks
** TODO Buy milk
line one
line two"
    [ "$(tail -n 4 "$NOTE")" = "$expected" ]
}

@test "append adds to the end of an existing section, before the next section" {
    daily-note append --section Tasks --key K1 --heading 'TODO First' </dev/null
    daily-note append --section Slack --key S1 --heading 'Slack thing' </dev/null
    daily-note append --section Tasks --key K2 --heading 'TODO Second' </dev/null

    expected="* Tasks
** TODO First
** TODO Second
* Slack
** Slack thing"
    [ "$(tail -n 5 "$NOTE")" = "$expected" ]
}

@test "append dedupes by key" {
    daily-note append --section Tasks --key K1 --heading 'TODO Buy milk' </dev/null
    run bash -c "daily-note append --section Tasks --key K1 --heading 'TODO Buy milk' </dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "skipped: K1" ]
    [ "$(grep -c 'TODO Buy milk' "$NOTE")" -eq 1 ]
}

@test "append with missing flags prints usage" {
    run bash -c "daily-note append --section Tasks </dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `bats test/daily-note.bats`
Expected: 3 passes (Task 1), 5 failures (append hits `usage`).

- [ ] **Step 3: Implement append**

In `bin/daily-note`, add `cmd_append` above the final `case`, and extend the `case`:

```bash
cmd_append() {
    local section="" key="" heading=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --section) section="$2"; shift 2 ;;
            --key)     key="$2";     shift 2 ;;
            --heading) heading="$2"; shift 2 ;;
            *) usage ;;
        esac
    done
    [ -n "$section" ] && [ -n "$key" ] && [ -n "$heading" ] || usage

    local file
    file=$(today_file)
    ensure_file "$file"

    if grep -qF -- "$key" "$file"; then
        echo "skipped: $key"
        return 0
    fi

    local body=""
    if [ ! -t 0 ]; then
        body=$(cat)
    fi

    # Ensure the section exists (new sections go at end of file)
    if ! grep -qxF -- "* $section" "$file"; then
        printf '* %s\n' "$section" >>"$file"
    fi

    local entry_file tmp
    entry_file=$(mktemp)
    tmp=$(mktemp)
    printf '** %s\n' "$heading" >"$entry_file"
    if [ -n "$body" ]; then
        printf '%s\n' "$body" >>"$entry_file"
    fi

    # Insert the entry at the end of the section: right before the next
    # top-level heading after it, or at EOF if it is the last section.
    awk -v hdr="* $section" -v ef="$entry_file" '
        function emit(    line) {
            while ((getline line < ef) > 0) print line
            close(ef)
            done = 1
        }
        /^\* / {
            if (insec && !done) emit()
            insec = ($0 == hdr)
        }
        { print }
        END { if (insec && !done) emit() }
    ' "$file" >"$tmp"

    mv "$tmp" "$file"
    rm -f "$entry_file"
    echo "added: $key"
}
```

Final dispatch becomes:

```bash
case "${1:-}" in
    path) cmd_path ;;
    append) shift; cmd_append "$@" ;;
    *) usage ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/daily-note.bats`
Expected: `8 tests, 0 failures`

- [ ] **Step 5: Link into ~/bin via bootstrap**

In `bootstrap`, after the line `maybe-link bin/jira-parent ~/bin/jira-parent`, add:

```fish
maybe-link bin/daily-note ~/bin/daily-note
```

Create the link now without running the whole bootstrap:

Run: `ln -sf ~/.dots/bin/daily-note ~/bin/daily-note && ~/bin/daily-note path`
Expected: prints `/Users/csims/org-roam/daily/<today>.org` (and creates it if today's note didn't exist — that's fine, it's the real target).

- [ ] **Step 6: Commit**

```bash
git add bin/daily-note test/daily-note.bats bootstrap
git commit -m "Add daily-note append with section handling and key dedupe"
```

---

### Task 3: `bin/things-to-daily`

**Files:**
- Create: `bin/things-to-daily`
- Create: `test/things-to-daily.bats`
- Modify: `bootstrap` (add symlink line)

**Interfaces:**
- Consumes: `daily-note append` exactly as produced by Task 2 (including `</dev/null`-free usage — this script always pipes a body).
- Consumes: `things` CLI — `things list <view> --tag <TAG> --json` (returns a JSON array, or the literal string `null` when empty; task objects have `uuid`, `title`, optional `notes`, optional `deadline` `YYYY-MM-DD`, optional `startDate` `YYYY-MM-DD`) and `things complete <uuid>`.
- Produces: `things-to-daily` — imports open `@work`-tagged tasks from views inbox/today/upcoming/anytime/someday into section `Tasks`, then completes each in Things. Prints `imported N task(s), skipped M duplicate(s)`.

Entry format written for each task (body piped to `daily-note append --section Tasks --key <uuid> --heading "TODO <title>"`):

```
DEADLINE: <2026-07-22> SCHEDULED: <2026-07-14>     <- line only present when dates exist
:PROPERTIES:
:THINGS_ID: <uuid>
:END:
<notes, if any>
```

- [ ] **Step 1: Write the failing tests**

Create `test/things-to-daily.bats`:

```bash
#!/usr/bin/env bats

setup() {
    export DAILY_DIR="$BATS_TEST_TMPDIR/daily"
    export FIXTURES="$BATS_TEST_TMPDIR/fixtures"
    export THINGS_LOG="$BATS_TEST_TMPDIR/things.log"
    STUB_DIR="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$FIXTURES" "$STUB_DIR"

    # Stub `things`: list serves fixture JSON per view; complete logs the call.
    cat >"$STUB_DIR/things" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    list)
        view="$2"
        f="$FIXTURES/$view.json"
        if [ -f "$f" ]; then cat "$f"; else echo null; fi
        ;;
    complete)
        echo "complete $2" >>"$THINGS_LOG"
        exit "${THINGS_COMPLETE_EXIT:-0}"
        ;;
    *)
        echo "unexpected things invocation: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$STUB_DIR/things"
    PATH="$STUB_DIR:$BATS_TEST_DIRNAME/../bin:$PATH"

    TODAY=$(date +%F)
    NOTE="$DAILY_DIR/$TODAY.org"
}

@test "imports a task with notes, completes it in Things" {
    cat >"$FIXTURES/inbox.json" <<'EOF'
[{"uuid": "U1", "title": "Ping Ben about the report job", "notes": "context line", "status": "open"}]
EOF
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 1 task(s), skipped 0 duplicate(s)"* ]]

    grep -qxF '** TODO Ping Ben about the report job' "$NOTE"
    grep -qxF ':THINGS_ID: U1' "$NOTE"
    grep -qxF 'context line' "$NOTE"
    [ "$(cat "$THINGS_LOG")" = "complete U1" ]
}

@test "maps deadline and startDate to DEADLINE/SCHEDULED" {
    cat >"$FIXTURES/today.json" <<'EOF'
[{"uuid": "U2", "title": "Dated task", "deadline": "2026-07-22", "startDate": "2026-07-14"}]
EOF
    run things-to-daily
    [ "$status" -eq 0 ]
    grep -qxF 'DEADLINE: <2026-07-22> SCHEDULED: <2026-07-14>' "$NOTE"
}

@test "same uuid across views is imported and completed once" {
    echo '[{"uuid": "U3", "title": "Dup"}]' >"$FIXTURES/inbox.json"
    echo '[{"uuid": "U3", "title": "Dup"}]' >"$FIXTURES/anytime.json"
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 1 task(s)"* ]]
    [ "$(grep -c '** TODO Dup' "$NOTE")" -eq 1 ]
    [ "$(wc -l <"$THINGS_LOG")" -eq 1 ]
}

@test "re-run skips the duplicate but still completes in Things" {
    echo '[{"uuid": "U4", "title": "Sticky"}]' >"$FIXTURES/inbox.json"
    things-to-daily
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 0 task(s), skipped 1 duplicate(s)"* ]]
    [ "$(grep -c '** TODO Sticky' "$NOTE")" -eq 1 ]
    [ "$(grep -c 'complete U4' "$THINGS_LOG")" -eq 2 ]
}

@test "complete failure warns but exits zero and keeps the entry" {
    echo '[{"uuid": "U5", "title": "Fragile"}]' >"$FIXTURES/inbox.json"
    export THINGS_COMPLETE_EXIT=1
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning: failed to complete task in Things: U5"* ]]
    grep -qxF '** TODO Fragile' "$NOTE"
}
```

Note on the warning assertion: bats' `run` merges stdout and stderr into `$output`, so the stderr warning is visible there.

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats test/things-to-daily.bats`
Expected: 5 failures (`things-to-daily: command not found`).

- [ ] **Step 3: Write the implementation**

Create `bin/things-to-daily` (mode 755):

```bash
#!/usr/bin/env bash
set -euo pipefail

# Import open Things tasks tagged $THINGS_TAG into today's org-roam daily
# note, then complete them in Things (one-way capture; org owns them now).

TAG="${THINGS_TAG:-@work}"
VIEWS=(inbox today upcoming anytime someday)

for cmd in things jq daily-note; do
    if ! command -v "$cmd" >/dev/null; then
        echo "missing required command: $cmd" >&2
        exit 1
    fi
done

imported=0
skipped=0
seen=" "

for view in "${VIEWS[@]}"; do
    tasks=$(things list "$view" --tag "$TAG" --json)
    if [ -z "$tasks" ] || [ "$tasks" = "null" ]; then
        continue
    fi

    while IFS= read -r task; do
        uuid=$(jq -r '.uuid' <<<"$task")

        # A task can show up in more than one view; handle it once.
        case "$seen" in *" $uuid "*) continue ;; esac
        seen="$seen$uuid "

        title=$(jq -r '.title' <<<"$task")
        notes=$(jq -r '.notes // empty' <<<"$task")
        deadline=$(jq -r '.deadline // empty' <<<"$task")
        scheduled=$(jq -r '.startDate // empty' <<<"$task")

        planning=""
        [ -n "$deadline" ] && planning="DEADLINE: <$deadline>"
        if [ -n "$scheduled" ]; then
            [ -n "$planning" ] && planning+=" "
            planning+="SCHEDULED: <$scheduled>"
        fi

        body=""
        [ -n "$planning" ] && body+="$planning"$'\n'
        body+=":PROPERTIES:"$'\n'":THINGS_ID: $uuid"$'\n'":END:"
        [ -n "$notes" ] && body+=$'\n'"$notes"

        if ! result=$(printf '%s\n' "$body" |
                          daily-note append --section Tasks --key "$uuid" \
                                     --heading "TODO $title"); then
            echo "warning: failed to write entry for: $uuid ($title)" >&2
            continue
        fi

        case "$result" in
            skipped:*) skipped=$((skipped + 1)) ;;
            *) imported=$((imported + 1)) ;;
        esac

        # Complete after a successful append OR a dedupe skip — either way
        # the task lives in org now. Failure here just means it lingers in
        # Things; the dedupe key prevents a duplicate on the next run.
        if ! things complete "$uuid"; then
            echo "warning: failed to complete task in Things: $uuid ($title)" >&2
        fi
    done < <(jq -c '.[]' <<<"$tasks")
done

echo "imported $imported task(s), skipped $skipped duplicate(s)"
```

Run: `chmod +x bin/things-to-daily`

Note: the `while` loop reads from process substitution (not a pipe) so `imported`/`skipped`/`seen` survive the loop.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/things-to-daily.bats`
Expected: `5 tests, 0 failures`

Also run the full suite: `bats test/`
Expected: `13 tests, 0 failures`

- [ ] **Step 5: Link into ~/bin via bootstrap**

In `bootstrap`, after the `maybe-link bin/daily-note ~/bin/daily-note` line added in Task 2, add:

```fish
maybe-link bin/things-to-daily ~/bin/things-to-daily
```

Run: `ln -sf ~/.dots/bin/things-to-daily ~/bin/things-to-daily`

Sanity-check against the real Things database (read-only preview — do NOT let it complete anything you didn't expect; check what's tagged first):

Run: `things list inbox --tag @work --json; things list today --tag @work --json`

If the output is `null`/empty everywhere, running `~/bin/things-to-daily` is a safe no-op smoke test: expected output `imported 0 task(s), skipped 0 duplicate(s)`. If real tagged tasks exist, leave the live run for the user.

- [ ] **Step 6: Commit**

```bash
git add bin/things-to-daily test/things-to-daily.bats bootstrap
git commit -m "Add things-to-daily one-way capture into the daily note"
```

---

### Task 4: Emacs — remove ~/org plumbing, restore org-roam + vulpea

**Files:**
- Modify: `emacs.d/init.el`

The restored code is the pre-`09aecd1` config (see `git show 09aecd1 -- emacs.d/init.el` for the removed block); it is reproduced in full below — no need to consult git history.

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `jcs/org-roam-dir` defvar (used by Task 5); org-roam loaded with dailies keybindings under `C-c o`; dynamic agenda from `project`-tagged roam files + Journelly.
- Keeps: `org-tag-alist` (recently updated), `org-dir`/`org-directory` (still `~/org`, harmless), everything else org-related.

- [ ] **Step 1: Remove the ~/org file vars**

In `emacs.d/init.el` (currently lines 491–496), replace:

```elisp
(defvar org-dir (file-truename "~/org"))

(defvar jcs/inbox-file (expand-file-name "inbox.org" org-dir))
(defvar jcs/meetings-file (expand-file-name "meetings.org" org-dir))
(defvar jcs/notes-file (expand-file-name "notes.org" org-dir))
(defvar jcs/work-file (expand-file-name "work.org" org-dir))
```

with:

```elisp
(defvar org-dir (file-truename "~/org"))
```

- [ ] **Step 2: Remove the refile targets**

In the `use-package org` `:config` `setq` (currently lines 538–540), delete these three lines:

```elisp
        org-refile-targets '((jcs/work-file . (:maxlevel . 2))
                             (jcs/meetings-file . (:level . 1))
                             (jcs/notes-file . (:level . 2)))
```

(the `org-todo-keywords` entry that follows stays).

- [ ] **Step 3: Remove the jcs/open-* helpers and their bindings**

Delete (currently lines 587–594):

```elisp
  (defun jcs/open-org-file (filename)
    "Open FILENAME in the defined `org-dir'."
    (find-file (expand-file-name filename org-dir)))

  (defun jcs/open-inbox () (interactive) (jcs/open-org-file "inbox.org"))
  (defun jcs/open-meetings () (interactive) (jcs/open-org-file "meetings.org"))
  (defun jcs/open-notes () (interactive) (jcs/open-org-file "notes.org"))
  (defun jcs/open-work () (interactive) (jcs/open-org-file "work.org"))
```

and in the `:bind` block right below, delete these three lines (keep `C-c l`, `C-c a`, and the map binding):

```elisp
         ("C-c e i" . jcs/open-inbox)
         ("C-c e m" . jcs/open-meetings)
         ("C-c e n" . jcs/open-notes)
```

- [ ] **Step 4: Restore vulpea + the dynamic agenda**

Immediately before the `(use-package org-agenda` line, add:

```elisp
(use-package vulpea)
```

Change the org-agenda header from `:after (org)` to `:after (org vulpea)`.

Replace the static agenda files setq (currently):

```elisp
  (setq org-agenda-window-setup 'current-window
        org-agenda-block-separator nil
        org-agenda-tags-column -80
        org-agenda-show-future-repeats nil
        org-agenda-files (list jcs/work-file
                               jcs/inbox-file
                               jcs/meetings-file))
```

with the vulpea-driven version:

```elisp
  (setq org-agenda-window-setup 'current-window
        org-agenda-block-separator nil
        org-agenda-tags-column -80
        org-agenda-show-future-repeats nil)

  ;; Stolen from
  ;; https://d12frosted.io/posts/2020-06-24-task-management-with-roam-vol2.html
  ;; This ensures that the label prior to the TODO in the agenda is
  ;; readable and sane. This is especially useful using org-roam,
  ;; since the filenames are prefixed with a timestamp, making the
  ;; usual pattern (the filename) useless.
  (setq org-agenda-prefix-format
        '((agenda . " %i %(vulpea-agenda-category 12)%?-12t% s")
          (todo . " %i %(vulpea-agenda-category 12) ")
          (tags . " %i %(vulpea-agenda-category 12) ")
          (search . " %i %(vulpea-agenda-category 12) ")))

  (defun vulpea-agenda-category (&optional len)
    "Get category of item at point for agenda.

     Category is defined by one of the following items:

     - CATEGORY property
     - TITLE keyword
     - TITLE property
     - filename without directory and extension

     When LEN is a number, resulting string is padded right with
     spaces and then truncated with ... on the right if result is
     longer than LEN.

     Usage example:

       (setq org-agenda-prefix-format
             '((agenda . \" %(vulpea-agenda-category) %?-12t %12s\")))

     Refer to `org-agenda-prefix-format' for more information."
    (let* ((file-name (when buffer-file-name
                        (file-name-sans-extension
                         (file-name-nondirectory buffer-file-name))))
           (title (vulpea-buffer-prop-get "title"))
           (category (org-get-category))
           (result
            (or (if (and
                     title
                     (string-equal category file-name))
                    title
                  category)
                "")))
      (if (numberp len)
          (s-truncate len (s-pad-right len " " result))
        result)))

  (defun vulpea-project-files ()
    "Return a list of org-roam files containing the `project' tag."
    (seq-uniq
     (seq-map
      #'car
      (org-roam-db-query
       [:select [nodes:file]
                :from tags
                :left-join nodes
                :on (= tags:node-id nodes:id)
                :where (like tag (quote "%\"project\"%"))]))))

  (defun vulpea-agenda-files-update (&rest _)
    "Update the value of `org-agenda-files' based on `project' tag."
    (setq org-agenda-files (-concat (vulpea-project-files)
                                    (list jcs/journelly-file))))

  (advice-add 'org-agenda :before #'vulpea-agenda-files-update)
  (advice-add 'org-todo-list :before #'vulpea-agenda-files-update)
```

- [ ] **Step 5: Restore the org-roam block**

After `(use-package org-mac-link)` (currently line 674), add:

```elisp
(defvar jcs/org-roam-dir (file-truename "~/org-roam"))

(use-package org-roam
  :after (org)
  :custom (org-roam-directory jcs/org-roam-dir)
  :bind (("C-c o l" . org-roam-buffer-toggle)
         ("C-c o f" . org-roam-node-find)
         ("C-c o i" . org-roam-node-insert)
         ("C-c o c" . org-roam-capture)
         ("C-c o r" . org-roam-refile)
         ;; Dailies
         ("C-c o d" . org-roam-dailies-goto-today)
         ("C-c o p" . org-roam-dailies-goto-previous-note)
         ("C-c o n" . org-roam-dailies-goto-next-note)
         ("C-c o j" . org-roam-dailies-capture-today))
  :hook ((find-file . vulpea-project-update-tag)
         (before-save . vulpea-project-update-tag))
  :config
  (org-roam-db-autosync-mode)
  ;; Help make agenda loading faster by only including org-roam files with
  ;; todo headers in the agenda files. Stolen from
  ;; https://d12frosted.io/posts/2021-01-16-task-management-with-roam-vol5.html
  (add-to-list 'org-tags-exclude-from-inheritance "project")

  (defun vulpea-project-p ()
    "Return non-nil if current buffer has any todo entry.

TODO entries marked as done are ignored, meaning this function
returns nil if current buffer contains only completed or
canceled tasks."
    (org-element-map
        (org-element-parse-buffer 'headline)
        'headline
      (lambda (headline)
        (eq (org-element-property :todo-type headline)
            'todo))
      nil
      'first-match))

  ;; Update org-roam node tags with a special tag to help filter
  ;; org-agenda buffers.

  (defun vulpea-project-update-tag ()
    "Update PROJECT tag in the current buffer."
    (when (and (not (active-minibuffer-window))
               (org-roam-buffer-p))
      (save-excursion
        (goto-char (point-min))
        (let* ((tags (vulpea-buffer-tags-get))
               (original-tags tags))
          (if (vulpea-project-p)
              (setq tags (cons "project" tags))
            (setq tags (remove "project" tags)))

          ;; Remove duplicates
          (setq tags (seq-uniq tags))

          ;; Update tags in the buffer if they've changed
          (when (or (seq-difference tags original-tags)
                    (seq-difference original-tags tags))
            (apply #'vulpea-buffer-tags-set tags))))))

  (defun org-roam-buffer-p ()
    "Return non-nil of the currently visited buffer is an org-roam buffer."
    (and buffer-file-name
         (string-prefix-p
          (expand-file-name (file-name-as-directory org-roam-directory))
          (file-name-as-directory buffer-file-name)))))
```

- [ ] **Step 6: Verify the config loads**

Run: `emacs --batch -l ~/.emacs.d/init.el --eval '(message "init loaded OK")' 2>&1 | tail -20`

Expected: ends with `init loaded OK`. First run may install vulpea/org-roam from MELPA (network, a minute or two). Any `Symbol's value as variable is void: jcs/work-file`-style error means a removal step missed a reference — search `init.el` for `jcs/work-file|jcs/inbox-file|jcs/meetings-file|jcs/notes-file|jcs/open-` (should be zero matches).

- [ ] **Step 7: Commit**

```bash
git add emacs.d/init.el
git commit -m "Restore org-roam + vulpea config, drop unused ~/org plumbing"
```

---

### Task 5: Emacs — `jcs/things-to-daily` command

**Files:**
- Modify: `emacs.d/init.el`

**Interfaces:**
- Consumes: `~/bin/things-to-daily` (Task 3, symlinked), `jcs/org-roam-dir` and the org-roam block (Task 4).
- Produces: interactive command `jcs/things-to-daily` on `C-c o t` — runs the import, reverts today's daily buffer if it's open (the file changed on disk), then jumps to today's daily note.

- [ ] **Step 1: Add the command**

In `emacs.d/init.el`, immediately after the `(use-package org-roam ...)` block added in Task 4, add:

```elisp
(defun jcs/things-to-daily ()
  "Import @work-tagged Things tasks into today's daily note, then open it."
  (interactive)
  (message "%s" (string-trim
                 (shell-command-to-string "~/bin/things-to-daily")))
  (let* ((daily (expand-file-name
                 (format-time-string "daily/%Y-%m-%d.org")
                 jcs/org-roam-dir))
         (buf (find-buffer-visiting daily)))
    (when buf
      (with-current-buffer buf
        (revert-buffer :ignore-auto :noconfirm))))
  (org-roam-dailies-goto-today))

(global-set-key (kbd "C-c o t") #'jcs/things-to-daily)
```

- [ ] **Step 2: Verify the config still loads**

Run: `emacs --batch -l ~/.emacs.d/init.el --eval '(message "init loaded OK")' 2>&1 | tail -5`
Expected: ends with `init loaded OK`.

- [ ] **Step 3: Commit**

```bash
git add emacs.d/init.el
git commit -m "Add jcs/things-to-daily command on C-c o t"
```

---

### Task 6: `/daily-context` skill

**Files:**
- Create: `config/claude/skills/daily-context/SKILL.md`
- Create: `config/claude/skills/daily-context/VERIFICATION.md`
- Modify: `bootstrap` (mkdir + two symlink lines)

**Interfaces:**
- Consumes: `daily-note append` CLI (Task 2) via `~/bin/daily-note`.
- Produces: the `/daily-context` skill available in Claude Code sessions.

- [ ] **Step 1: Write SKILL.md**

Create `config/claude/skills/daily-context/SKILL.md`:

````markdown
---
name: daily-context
description: Use when the user runs /daily-context or asks to pull today's Slack, Jira, Confluence, or Google Docs activity into their org-roam daily note. Gathers today's cloud activity via MCP connectors and writes deduplicated entries with the daily-note CLI.
---

# daily-context — today's cloud activity → org-roam daily note

Pull today's activity from Slack, Jira, Confluence, and Google Docs into
`~/org-roam/daily/YYYY-MM-DD.org`. Things 3 import is handled separately by
`things-to-daily` — do NOT run it from this skill.

## Orchestration (IMPORTANT)

Do NOT gather MCP data in the main session — dispatch all four verticals as
parallel subagents in a single message (Agent tool, subagent_type:
general-purpose). Models: `haiku` for Jira, Confluence, and Docs; `sonnet`
for Slack (thread summaries need a little judgment).

Each subagent prompt must contain, verbatim: the Writing rules section below,
that vertical's section below, and today's date (YYYY-MM-DD, local time).
Subagents load MCP tool schemas with ToolSearch as needed.

When all subagents return, print a run summary: entries added / skipped as
duplicates per section, and anything that degraded (auth failure, unsupported
query, missing connector) — never fail the whole run because one vertical
failed.

## Writing rules (include verbatim in every subagent prompt)

- Write entries ONLY with the `daily-note` CLI (Bash tool); never edit org
  files directly:

  ```
  printf '%s\n' "<body>" | daily-note append --section <Section> --key '<KEY>' --heading '<HEADING>'
  ```

  or with no body:

  ```
  daily-note append --section <Section> --key '<KEY>' --heading '<HEADING>' </dev/null
  ```

- `skipped: <KEY>` output means the entry already exists — count it as a
  duplicate, not an error.
- The KEY must appear in the heading or body. Headings are org links, so a
  heading like `[[<url>][<description>]]` with KEY=<url> satisfies this.
- Maximum 50 entries for your section; keep the most recent if over.
- Skip bot/app messages and automated notifications.
- Summaries: 1–2 lines, factual, no editorializing, do not invent TODOs.
- Report back: added / skipped / errors counts and any degradation notes.

## Slack (section: Slack, model: sonnet)

1. Resolve my identity (slack_search_users for my display name if needed).
2. Threads I posted in today: `slack_search_public_and_private` with
   `from:me` scoped to today. Group results by thread; for each unique
   thread, `slack_read_thread` and write a one-line factual topic summary.
   - Heading: `[[<permalink>][#<channel>: <topic>]]`
   - Body: the 1–2 line summary
   - Key: the message permalink
3. Mentions of me today (search for my @handle), excluding threads already
   captured in step 2. Same entry shape.
4. Saved for later: try search with the `is:saved` modifier. If the connector
   rejects it or results look unavailable, skip and add
   "saved-for-later unavailable via connector" to your report.

## Jira (section: Jira, model: haiku)

1. `getAccessibleAtlassianResources` for the cloudId; `atlassianUserInfo` for
   my identity.
2. `searchJiraIssuesUsingJql`:
   `updated >= startOfDay() AND (assignee = currentUser() OR reporter = currentUser()) ORDER BY updated DESC`
   Additionally try
   `issuekey IN updatedBy(currentUser(), startOfDay()) ORDER BY updated DESC`
   to catch issues I touched but don't own; if that function is unsupported,
   proceed with the first query alone and note it in your report.
3. Per issue — heading: `[[https://<site>.atlassian.net/browse/<KEY>][<KEY>: <summary>]] — <what I did>`
   where "what I did" is created / commented / transitioned / updated (from
   the changelog/comments when cheap to determine; otherwise "updated").
   Key: the issue key (e.g. `RENG-1234`). No body needed.

## Confluence (section: Confluence, model: haiku)

1. `searchConfluenceUsingCql`:
   `contributor = currentUser() and lastmodified >= startOfDay() order by lastmodified desc`
2. Per page — heading: `[[<page-url>][<page title>]] — edited`
   (use `— commented` when the result is clearly a comment contribution).
   Key: the page URL. No body needed.

## Google Docs (section: Docs, model: haiku)

1. `search_files` (Google Drive connector) for files modified today with
   `modifiedByMe`; restrict to Docs/Sheets/Slides types.
2. Per file — heading: `[[<webViewLink>][<file name>]] — edited`.
   Key: the file's webViewLink URL. No body needed.
3. Comment activity is only capturable if the connector exposes it; if not,
   note "Docs comment activity unavailable" in your report rather than
   guessing.
````

- [ ] **Step 2: Write VERIFICATION.md**

Create `config/claude/skills/daily-context/VERIFICATION.md`:

```markdown
# Manual verification checklist for /daily-context

Run these after changing the skill (there is no automated test for MCP flows):

1. In a fresh Claude Code session, run `/daily-context`.
2. Confirm four subagents dispatch in parallel (Slack on sonnet, rest on haiku).
3. Open today's `~/org-roam/daily/YYYY-MM-DD.org`:
   - Entries appear under `* Slack` / `* Jira` / `* Confluence` / `* Docs`.
   - Headings are valid org links; summaries are 1–2 factual lines.
   - Nothing edited outside those sections; Tasks section untouched.
4. Run `/daily-context` again immediately: the summary should report
   duplicates skipped, and the file should gain no repeated entries.
5. Check the run summary reports any degraded vertical (e.g. saved-for-later)
   instead of failing.
```

- [ ] **Step 3: Wire up bootstrap**

In `bootstrap`:

- Change the mkdir line (line 22) from:

```fish
mkdir -p ~/bin ~/.claude/skills/jira ~/.emacs.d/lisp ~/Library/KeyBindings
```

to:

```fish
mkdir -p ~/bin ~/.claude/skills/jira ~/.claude/skills/daily-context ~/.emacs.d/lisp ~/Library/KeyBindings
```

- After the `maybe-link config/claude/skills/jira/SKILL.md ...` line, add:

```fish
maybe-link config/claude/skills/daily-context/SKILL.md ~/.claude/skills/daily-context/SKILL.md
maybe-link config/claude/skills/daily-context/VERIFICATION.md ~/.claude/skills/daily-context/VERIFICATION.md
```

Create the links now:

```bash
mkdir -p ~/.claude/skills/daily-context
ln -sf ~/.dots/config/claude/skills/daily-context/SKILL.md ~/.claude/skills/daily-context/SKILL.md
ln -sf ~/.dots/config/claude/skills/daily-context/VERIFICATION.md ~/.claude/skills/daily-context/VERIFICATION.md
```

Verify: `ls -la ~/.claude/skills/daily-context/` shows both symlinks resolving into `~/.dots`.

- [ ] **Step 4: Commit**

```bash
git add config/claude/skills/daily-context bootstrap
git commit -m "Add daily-context skill for Slack/Jira/Confluence/Docs capture"
```

- [ ] **Step 5: Manual verification (user)**

The skill only registers in a fresh session. Ask the user to open a new
Claude Code session, run `/daily-context`, and walk
`config/claude/skills/daily-context/VERIFICATION.md`. Fix anything that
surfaces before calling the task done.
