# Todo helpers: LLM-friendly editing, IDs, and tags — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add machine-addressable IDs, `@tag` categories, and edit/note/tag/show commands to the fish `todo` helpers so an LLM (and the user) can maintain `~/todo.md` reliably, plus a skill + `--help` for discoverability.

**Architecture:** Keep the single markdown file (`## Doing` / `# Todo` / `## Archive`). Introduce a block-aware parsing rule (a task = its line plus every following line until the next task line or header) implemented as small shared fish helpers, so context lines travel with their task regardless of indentation. Each task line gains a trailing `@tag` (optional) and `(id)` (3-char base36). `_todo_write` backfills missing IDs and normalizes context indentation on every write.

**Tech Stack:** fish 4.7 functions (autoloaded from `config/fish/functions/`), a fish test script, a Claude Code skill (`SKILL.md`), `bootstrap` symlinks.

---

## Conventions used throughout

- **Task-line regex:** a task line matches `^\s*- \[[ xX]\]`. A completed task matches `^\s*- \[x\]`.
- **Canonical task line:** `- [ ] <text> @<tag> (<id>)` — `@tag` and `(id)` are optional tokens at the end, tag before id.
- **ID token:** trailing `(xxx)` where `xxx` is exactly 3 chars from `a–z0–9` → regex `\([a-z0-9]{3}\)\s*$`.
- **Tag token (on read):** a trailing `@<non-space>` (after the id is stripped) → regex `@\S+\s*$`.
- **Parsed-line globals:** `_todo_split` sets `__td_checked` (0/1), `__td_id`, `__td_tag`, `__td_text`.
- **Section globals:** `_todo_read` sets `__td_doing`, `__td_todo`, `__td_archive` (raw line arrays).
- **File path:** every command resolves its file via `_todo_file` (honors `$TODO_FILE`, else `~/todo.md`). This is what makes the suite testable without touching the real file.

## File structure

New helper files (one function each, `config/fish/functions/`):

| File | Responsibility |
|---|---|
| `_todo_file.fish` | Resolve file path (`$TODO_FILE` override else `~/todo.md`) |
| `_todo_split.fish` | Parse a task line → `__td_checked/__td_id/__td_tag/__td_text` |
| `_todo_line.fish` | Build a canonical task line from checked/id/tag/text |
| `_todo_gen_id.fish` | Generate a 3-char base36 id not in a given list |
| `_todo_block_end.fish` | Last line index of the block starting at idx |
| `_todo_find_id.fish` | Locate a task by id across loaded sections → "section idx" |
| `_todo_get_line.fish` | Echo line idx of a section global |
| `_todo_set_line.fish` | Replace line idx of a section global |
| `_todo_get_block.fish` | Echo the block at idx (non-destructive) |
| `_todo_take_block.fish` | Remove and echo the block at idx |
| `_todo_splice.fish` | Echo an array with a line inserted after a position |
| `_todo_append_to_block.fish` | Insert a line at the end of a task's block |
| `_todo_canon.fish` | Canonicalize a section's blocks (assign ids, normalize indent) |
| `_todo_usage.fish` | `todo` usage / help text |

Modified: `_todo_write.fish`, `todo.fish`, `doing.fish`, `done.fish`, `next.fish`, `archive.fish`.
Unchanged: `_todo_read.fish`. Removed: `_todo_strip.fish` (dead after the write rewrite).
New non-fish: `config/claude/skills/todo/SKILL.md`, `test/todo_helpers.fish`. Modified: `bootstrap`.

---

### Task 1: Test harness + `_todo_file` path override

**Files:**
- Create: `test/todo_helpers.fish`
- Create: `config/fish/functions/_todo_file.fish`
- Modify: `config/fish/functions/{todo,doing,done,next,archive}.fish` (swap `set -l file ~/todo.md` → `set -l file (_todo_file)`)

- [ ] **Step 1: Write the test harness**

Create `test/todo_helpers.fish`:

```fish
#!/usr/bin/env fish
# Run: fish test/todo_helpers.fish [filter]
# Sources the repo's fish functions (not the installed symlinks) and runs
# assertions against a temp TODO_FILE. Optional filter substring-matches labels.

set -g repo (realpath (status dirname)/..)
set -g fish_function_path $repo/config/fish/functions $fish_function_path
set -g _filter ''
test (count $argv) -ge 1; and set _filter $argv[1]

set -g _pass 0
set -g _fail 0

function setup --argument-names content
    set -g TODO_FILE (mktemp)
    printf '%s' "$content" >$TODO_FILE
end

function teardown
    test -n "$TODO_FILE"; and rm -f $TODO_FILE
    set -e TODO_FILE
end

function check --argument-names label actual expected
    if test -n "$_filter"; and not string match -q "*$_filter*" -- $label
        return 0
    end
    if test "$actual" = "$expected"
        set _pass (math $_pass + 1)
        echo "ok   - $label"
    else
        set _fail (math $_fail + 1)
        echo "FAIL - $label"
        echo "       expected: [$expected]"
        echo "       actual:   [$actual]"
    end
end

# A canonical sample file used by several tests.
set -g SAMPLE "## Doing

- [ ] First doing task @turbo (aaa)

# Todo

- [ ] Backlog one (bbb)
- [ ] Backlog two @admin (ccc)
  context line for two

## Archive

- [x] Old done (ddd)
"

# --- tests are appended below by later tasks ---

echo ""
echo "passed: $_pass   failed: $_fail"
exit (test $_fail -eq 0; and echo 0; or echo 1)
```

- [ ] **Step 2: Add a sanity test above the summary block**

Insert before the `echo ""`/summary lines:

```fish
setup "$SAMPLE"
check "harness: file written" (head -1 $TODO_FILE) "## Doing"
teardown
```

- [ ] **Step 3: Run it to verify it fails (no `_todo_file` yet is fine; this test doesn't need it, but functions reference it)**

Run: `fish test/todo_helpers.fish harness`
Expected: `ok   - harness: file written` and `passed: 1   failed: 0`. (If fish errors that `_todo_file` is undefined when sourcing, that's expected until Step 4 — proceed.)

- [ ] **Step 4: Create `_todo_file.fish`**

```fish
function _todo_file --description "Resolve the todo file path (TODO_FILE override, else ~/todo.md)"
    if set -q TODO_FILE; and test -n "$TODO_FILE"
        echo $TODO_FILE
    else
        echo ~/todo.md
    end
end
```

- [ ] **Step 5: Point each command at `_todo_file`**

In each of `todo.fish`, `doing.fish`, `done.fish`, `next.fish`, `archive.fish`, replace the line `set -l file ~/todo.md` with:

```fish
    set -l file (_todo_file)
```

- [ ] **Step 6: Run the harness, confirm green**

Run: `fish test/todo_helpers.fish harness`
Expected: `passed: 1   failed: 0`

- [ ] **Step 7: Commit**

```bash
git add test/todo_helpers.fish config/fish/functions/_todo_file.fish config/fish/functions/{todo,doing,done,next,archive}.fish
git commit -m "test: add fish todo harness; route helpers through _todo_file"
```

---

### Task 2: `_todo_split` and `_todo_line`

**Files:**
- Create: `config/fish/functions/_todo_split.fish`, `config/fish/functions/_todo_line.fish`
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append above the summary block in `test/todo_helpers.fish`:

```fish
_todo_split "- [ ] Hello world @turbo (a1z)"
check "split: checked"  $__td_checked "0"
check "split: id"       $__td_id      "a1z"
check "split: tag"      $__td_tag     "turbo"
check "split: text"     $__td_text    "Hello world"

_todo_split "  - [x] Done thing"
check "split: checked done" $__td_checked "1"
check "split: id empty"     "$__td_id"    ""
check "split: tag empty"    "$__td_tag"   ""
check "split: text only"    $__td_text    "Done thing"

check "line: full"   (_todo_line 0 a1z turbo "Hello world") "- [ ] Hello world @turbo (a1z)"
check "line: done"   (_todo_line 1 ddd "" "Old done")       "- [x] Old done (ddd)"
check "line: notag"  (_todo_line 0 bbb "" "Plain")          "- [ ] Plain (bbb)"
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish split` then `fish test/todo_helpers.fish line`
Expected: FAIL (functions undefined / wrong output).

- [ ] **Step 3: Create `_todo_split.fish`**

```fish
function _todo_split --description "Parse a task line into globals __td_checked/__td_id/__td_tag/__td_text"
    set -l line $argv[1]

    set -g __td_checked 0
    string match -qr '^\s*- \[x\]' -- $line; and set -g __td_checked 1

    set -l body (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $line)

    set -g __td_id ''
    if string match -qr '\([a-z0-9]{3}\)\s*$' -- $body
        set -g __td_id (string match -rg '\(([a-z0-9]{3})\)\s*$' -- $body)
        set body (string replace -r '\s*\([a-z0-9]{3}\)\s*$' '' -- $body)
    end

    set -g __td_tag ''
    if string match -qr '@\S+\s*$' -- $body
        set -g __td_tag (string match -rg '@(\S+)\s*$' -- $body)
        set body (string replace -r '\s*@\S+\s*$' '' -- $body)
    end

    set -g __td_text (string trim -- $body)
end
```

- [ ] **Step 4: Create `_todo_line.fish`**

```fish
function _todo_line --description "Build a canonical task line from checked/id/tag/text"
    set -l checked $argv[1]
    set -l id $argv[2]
    set -l tag $argv[3]
    set -l text $argv[4]

    set -l box '[ ]'
    test "$checked" = 1; and set box '[x]'

    set -l out "- $box $text"
    test -n "$tag"; and set out "$out @$tag"
    test -n "$id"; and set out "$out ($id)"
    echo $out
end
```

- [ ] **Step 5: Run to verify pass**

Run: `fish test/todo_helpers.fish split` then `fish test/todo_helpers.fish line`
Expected: all `ok`.

- [ ] **Step 6: Commit**

```bash
git add config/fish/functions/_todo_split.fish config/fish/functions/_todo_line.fish test/todo_helpers.fish
git commit -m "feat: add _todo_split/_todo_line task-line parse and build"
```

---

### Task 3: `_todo_gen_id`

**Files:**
- Create: `config/fish/functions/_todo_gen_id.fish`
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
set -g _gid (_todo_gen_id)
check "genid: format" (string match -rq '^[a-z0-9]{3}$' -- $_gid; and echo yes) "yes"

# Never returns an id already in the exclude list.
set -g _seen
for i in (seq 200)
    set -l g (_todo_gen_id aaa bbb ccc $_seen)
    if contains -- $g aaa bbb ccc
        set -a _seen COLLISION
    end
end
check "genid: avoids excluded" (contains -- COLLISION $_seen; and echo bad; or echo good) "good"
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish genid`
Expected: FAIL (undefined).

- [ ] **Step 3: Create `_todo_gen_id.fish`**

```fish
function _todo_gen_id --description "Generate a 3-char base36 id not present in argv (the existing ids)"
    set -l chars a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9
    while true
        set -l id $chars[(random 1 36)]$chars[(random 1 36)]$chars[(random 1 36)]
        if not contains -- $id $argv
            echo $id
            return 0
        end
    end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish genid`
Expected: `ok` for both.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/_todo_gen_id.fish test/todo_helpers.fish
git commit -m "feat: add _todo_gen_id collision-checked id generator"
```

---

### Task 4: `_todo_block_end`

**Files:**
- Create: `config/fish/functions/_todo_block_end.fish`
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
set -g _lines "- [ ] one (aaa)" "  ctx a" "https://x" "- [ ] two (bbb)" "  ctx b"
check "blockend: first block incl flush-left ctx" (_todo_block_end 1 $_lines) "3"
check "blockend: second block to end"             (_todo_block_end 4 $_lines) "5"
set -g _single "- [ ] only (aaa)"
check "blockend: single line block" (_todo_block_end 1 $_single) "1"
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish blockend`
Expected: FAIL.

- [ ] **Step 3: Create `_todo_block_end.fish`**

```fish
function _todo_block_end --description "Index of the last line of the task block starting at idx. Usage: _todo_block_end <idx> <lines...>"
    set -l idx $argv[1]
    set -l lines $argv[2..-1]
    set -l n (count $lines)

    set -l endi $idx
    set -l k (math $idx + 1)
    while test $k -le $n
        if string match -qr '^\s*- \[[ xX]\]' -- $lines[$k]
            break
        end
        set endi $k
        set k (math $k + 1)
    end
    echo $endi
end
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish blockend`
Expected: all `ok`. (Confirms flush-left context is absorbed into the block — the orphan-bug fix.)

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/_todo_block_end.fish test/todo_helpers.fish
git commit -m "feat: add _todo_block_end indentation-independent block rule"
```

---

### Task 5: Rewrite `_todo_write` with backfill + normalization (`_todo_canon`)

**Files:**
- Create: `config/fish/functions/_todo_canon.fish`
- Modify: `config/fish/functions/_todo_write.fish`
- Delete: `config/fish/functions/_todo_strip.fish`
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append. These read the existing file, write it back, and assert backfill + indentation normalization:

```fish
# Flush-left context + a task missing an id, like the real file.
setup "## Doing

- [ ] Has flush-left ctx
https://example.com/x

# Todo

- [ ] Already has id (bbb)

## Archive
"
_todo_read $TODO_FILE
_todo_write $TODO_FILE
set -g _out (cat $TODO_FILE)

# Context line is now indented two spaces (not orphaned, not flush-left).
check "write: ctx indented" (string match -q '*\n  https://example.com/x\n*' -- (string join \n $_out)\n; and echo yes; or echo no) "yes"
# The id-less task now has a 3-char id.
check "write: backfilled id" (string match -rq '^- \[ \] Has flush-left ctx \([a-z0-9]{3}\)$' -- $_out[3]; and echo yes; or echo no) "yes"
# The existing id is preserved.
check "write: keeps existing id" (string match -q '*(bbb)*' -- (string join ' ' $_out); and echo yes; or echo no) "yes"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish write`
Expected: FAIL (old `_todo_write` neither backfills nor indents flush-left context).

- [ ] **Step 3: Create `_todo_canon.fish`**

```fish
function _todo_canon --description "Echo canonical task-block lines for a section. Assigns ids using/extending the global __td_ids pool; normalizes context to 2-space indent."
    set -l lines $argv
    set -l n (count $lines)
    set -l out
    set -l i 1
    while test $i -le $n
        set -l line $lines[$i]
        if test -z (string trim -- "$line")
            set i (math $i + 1)
            continue
        end
        if string match -qr '^\s*- \[[ xX]\]' -- $line
            _todo_split $line
            set -l id $__td_id
            test -z "$id"; and set id (_todo_gen_id $__td_ids)
            set -a __td_ids $id
            set -a out (_todo_line $__td_checked $id "$__td_tag" "$__td_text")

            set -l end (_todo_block_end $i $lines)
            for k in (seq (math $i + 1) $end)
                set -l c $lines[$k]
                test -z (string trim -- "$c"); and continue
                set -a out "  "(string trim -- "$c")
            end
            set i (math $end + 1)
        else
            # Should not occur after _todo_read's guard; preserve to avoid data loss.
            set -a out $line
            set i (math $i + 1)
        end
    end
    test (count $out) -gt 0; and printf '%s\n' $out
end
```

- [ ] **Step 4: Rewrite `_todo_write.fish`**

```fish
function _todo_write --description "Write the __td_doing/__td_todo/__td_archive globals back to a todo file in canonical form (ids assigned, context normalized)"
    set -l file $argv[1]

    # Pre-seed the id pool with every existing id so generated ids never
    # collide with an id that lives in a section processed later.
    set -g __td_ids
    for line in $__td_doing $__td_todo $__td_archive
        if string match -qr '\([a-z0-9]{3}\)\s*$' -- $line
            set -a __td_ids (string match -rg '\(([a-z0-9]{3})\)\s*$' -- $line)
        end
    end

    set -l doing (_todo_canon $__td_doing)
    set -l todo (_todo_canon $__td_todo)
    set -l archive (_todo_canon $__td_archive)
    set -e __td_ids

    set -l out
    set -a out "## Doing"
    test (count $doing) -gt 0; and set -a out "" $doing
    set -a out "" "# Todo"
    test (count $todo) -gt 0; and set -a out "" $todo
    set -a out "" "## Archive"
    test (count $archive) -gt 0; and set -a out "" $archive

    printf '%s\n' $out >$file

    set -e __td_doing __td_todo __td_archive
end
```

- [ ] **Step 5: Delete the now-dead `_todo_strip.fish`**

```bash
git rm config/fish/functions/_todo_strip.fish
```

- [ ] **Step 6: Run to verify pass**

Run: `fish test/todo_helpers.fish write`
Expected: all `ok`.

- [ ] **Step 7: Commit**

```bash
git add config/fish/functions/_todo_canon.fish config/fish/functions/_todo_write.fish test/todo_helpers.fish
git commit -m "feat: backfill ids and normalize context indentation on write"
```

---

### Task 6: By-id plumbing helpers

**Files:**
- Create: `config/fish/functions/_todo_find_id.fish`, `_todo_get_line.fish`, `_todo_set_line.fish`, `_todo_get_block.fish`, `_todo_take_block.fish`, `_todo_splice.fish`, `_todo_append_to_block.fish`
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
_todo_read $TODO_FILE
check "find: locates ccc" (_todo_find_id ccc) "todo 2"
check "find: locates aaa" (_todo_find_id aaa) "doing 1"
check "find: missing"     (_todo_find_id zzz; and echo found; or echo none) "none"
check "getline: ccc"      (_todo_get_line todo 2) "- [ ] Backlog two @admin (ccc)"

_todo_set_line todo 1 "- [ ] Changed (bbb)"
check "setline: applied" $__td_todo[1] "- [ ] Changed (bbb)"

check "getblock: ccc has ctx" (count (_todo_get_block todo 2)) "2"

_todo_append_to_block todo 1 "  a new note"
check "append: inserted after block" $__td_todo[2] "  a new note"

set -g _taken (_todo_take_block todo 1)
check "take: returned the line" $_taken[1] "- [ ] Changed (bbb)"
check "take: removed from section" $__td_todo[1] "  a new note"
teardown

check "splice: mid"  (string join '|' (_todo_splice 1 NEW a b c)) "a|NEW|b|c"
check "splice: end"  (string join '|' (_todo_splice 3 NEW a b c)) "a|b|c|NEW"
check "splice: empty" (_todo_splice 0 NEW) "NEW"
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish find` (and `getline`, `setline`, `getblock`, `append`, `take`, `splice`)
Expected: FAIL.

- [ ] **Step 3: Create `_todo_find_id.fish`**

```fish
function _todo_find_id --description "Find a task by id across loaded sections; echoes 'section idx' or returns 1"
    set -l want $argv[1]
    for section in doing todo archive
        set -l lines
        switch $section
            case doing
                set lines $__td_doing
            case todo
                set lines $__td_todo
            case archive
                set lines $__td_archive
        end
        for i in (seq (count $lines))
            string match -qr '^\s*- \[[ xX]\]' -- $lines[$i]; or continue
            _todo_split $lines[$i]
            if test "$__td_id" = "$want"
                echo "$section $i"
                return 0
            end
        end
    end
    return 1
end
```

- [ ] **Step 4: Create `_todo_get_line.fish`**

```fish
function _todo_get_line --description "Echo line idx of a section global (doing/todo/archive)"
    switch $argv[1]
        case doing
            echo $__td_doing[$argv[2]]
        case todo
            echo $__td_todo[$argv[2]]
        case archive
            echo $__td_archive[$argv[2]]
    end
end
```

- [ ] **Step 5: Create `_todo_set_line.fish`**

```fish
function _todo_set_line --description "Replace line idx of a section global (doing/todo/archive)"
    set -l sec $argv[1]
    set -l idx $argv[2]
    set -l line $argv[3]
    switch $sec
        case doing
            set -g __td_doing[$idx] $line
        case todo
            set -g __td_todo[$idx] $line
        case archive
            set -g __td_archive[$idx] $line
    end
end
```

- [ ] **Step 6: Create `_todo_get_block.fish`**

```fish
function _todo_get_block --description "Echo the task block at idx in a section global, non-destructively"
    set -l sec $argv[1]
    set -l idx $argv[2]
    switch $sec
        case doing
            printf '%s\n' $__td_doing[$idx..(_todo_block_end $idx $__td_doing)]
        case todo
            printf '%s\n' $__td_todo[$idx..(_todo_block_end $idx $__td_todo)]
        case archive
            printf '%s\n' $__td_archive[$idx..(_todo_block_end $idx $__td_archive)]
    end
end
```

- [ ] **Step 7: Create `_todo_take_block.fish`**

```fish
function _todo_take_block --description "Remove and echo the task block at idx in a section global"
    set -l sec $argv[1]
    set -l idx $argv[2]
    switch $sec
        case doing
            set -l end (_todo_block_end $idx $__td_doing)
            printf '%s\n' $__td_doing[$idx..$end]
            set -e __td_doing[$idx..$end]
        case todo
            set -l end (_todo_block_end $idx $__td_todo)
            printf '%s\n' $__td_todo[$idx..$end]
            set -e __td_todo[$idx..$end]
        case archive
            set -l end (_todo_block_end $idx $__td_archive)
            printf '%s\n' $__td_archive[$idx..$end]
            set -e __td_archive[$idx..$end]
    end
end
```

- [ ] **Step 8: Create `_todo_splice.fish`**

```fish
function _todo_splice --description "Echo args[3..] with <line> inserted after position idx. Usage: _todo_splice <idx> <line> <arr...>"
    set -l idx $argv[1]
    set -l line $argv[2]
    set -l arr $argv[3..-1]
    set -l n (count $arr)
    if test $n -eq 0
        echo $line
        return
    end
    for i in (seq $n)
        echo $arr[$i]
        test $i -eq $idx; and echo $line
    end
end
```

- [ ] **Step 9: Create `_todo_append_to_block.fish`**

```fish
function _todo_append_to_block --description "Insert a line at the end of the task block at idx in a section global"
    set -l sec $argv[1]
    set -l idx $argv[2]
    set -l line $argv[3]
    switch $sec
        case doing
            set -g __td_doing (_todo_splice (_todo_block_end $idx $__td_doing) "$line" $__td_doing)
        case todo
            set -g __td_todo (_todo_splice (_todo_block_end $idx $__td_todo) "$line" $__td_todo)
        case archive
            set -g __td_archive (_todo_splice (_todo_block_end $idx $__td_archive) "$line" $__td_archive)
    end
end
```

- [ ] **Step 10: Run to verify pass**

Run: `fish test/todo_helpers.fish find`, then `getline getline setline getblock append take splice` (or run the whole suite: `fish test/todo_helpers.fish`).
Expected: all `ok`.

- [ ] **Step 11: Commit**

```bash
git add config/fish/functions/_todo_find_id.fish config/fish/functions/_todo_get_line.fish config/fish/functions/_todo_set_line.fish config/fish/functions/_todo_get_block.fish config/fish/functions/_todo_take_block.fish config/fish/functions/_todo_splice.fish config/fish/functions/_todo_append_to_block.fish test/todo_helpers.fish
git commit -m "feat: add by-id section plumbing helpers"
```

---

### Task 7: `todo` dispatcher + `add` + `_todo_usage`

**Files:**
- Modify: `config/fish/functions/todo.fish` (full rewrite into a dispatcher)
- Create: `config/fish/functions/_todo_usage.fish`
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
todo add Brand new task >/dev/null
_todo_read $TODO_FILE
check "add: appended to todo" (string match -rq '^- \[ \] Brand new task \([a-z0-9]{3}\)$' -- $__td_todo[-1]; and echo yes; or echo no) "yes"
teardown

setup "$SAMPLE"
todo add Tagged item @lender >/dev/null
_todo_read $TODO_FILE
check "add: parses trailing tag" (string match -rq '^- \[ \] Tagged item @lender \([a-z0-9]{3}\)$' -- $__td_todo[-1]; and echo yes; or echo no) "yes"
teardown

setup "$SAMPLE"
check "dispatch: unknown cmd exits 1" (todo bogus 2>/dev/null; echo $status) "1"
check "dispatch: bare todo exits 1"   (todo 2>/dev/null; echo $status) "1"
check "help: mentions add"            (todo --help | string match -q '*todo add*'; and echo yes; or echo no) "yes"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish add` then `dispatch` then `help`
Expected: FAIL (current `todo` only adds, has no subcommands/help).

- [ ] **Step 3: Create `_todo_usage.fish`**

```fish
function _todo_usage --description "Print todo command usage"
    echo "todo — manage ~/todo.md (override the path with \$TODO_FILE)"
    echo ""
    echo "Tasks live in three sections (## Doing / # Todo / ## Archive). Each task"
    echo "line is  '- [ ] <text> @<tag> (<id>)'  with optional indented context lines."
    echo ""
    echo "Commands:"
    echo "  todo add <text> [@tag]    Add a task to the backlog"
    echo "  todo edit <id> <text>     Replace a task's text (trailing @tag updates the tag)"
    echo "  todo note <id> <text>     Append an indented context line to a task"
    echo "  todo tag <id> <tag|->     Set, or clear (-), a task's @tag"
    echo "  todo show <id>            Print a task and its context"
    echo ""
    echo "Lifecycle (separate commands):"
    echo "  doing [<id>|<text>]       Promote a task to Doing, or add an interruption"
    echo "  done [<id>]               Mark a task done"
    echo "  next [n] [@tag]           Show Doing + next n backlog tasks (filter by @tag)"
    echo "  archive                   Move completed tasks to Archive"
end
```

- [ ] **Step 4: Rewrite `todo.fish` as a dispatcher** (this version includes only `add`, `show`-less; later tasks add `edit`/`note`/`tag`/`show` cases):

```fish
function todo --description "Manage ~/todo.md: add/edit/note/tag/show tasks. Run 'todo --help'."
    set -l file (_todo_file)

    if test (count $argv) -eq 0
        _todo_usage >&2
        return 1
    end

    set -l cmd $argv[1]
    set -l rest $argv[2..-1]

    switch $cmd
        case add
            if test (count $rest) -eq 0
                echo "Usage: todo add <task text> [@tag]" >&2
                return 1
            end
            if not test -f $file
                echo "No todo.md found"
                return 1
            end
            _todo_read $file; or return 1
            set -l text (string join ' ' $rest)
            set -l tag ''
            if string match -qr '@\S+\s*$' -- $text
                set tag (string match -rg '@(\S+)\s*$' -- $text)
                set text (string replace -r '\s*@\S+\s*$' '' -- $text)
            end
            set text (string trim -- $text)
            set -a __td_todo (_todo_line 0 '' "$tag" "$text")
            _todo_write $file
            test -n "$tag"; and echo "Todo: $text @$tag"; or echo "Todo: $text"

        case -h --help
            _todo_usage

        case '*'
            echo "todo: unknown command '$cmd'" >&2
            _todo_usage >&2
            return 1
    end
end
```

- [ ] **Step 5: Run to verify pass**

Run: `fish test/todo_helpers.fish add` then `dispatch` then `help`
Expected: all `ok`.

- [ ] **Step 6: Commit**

```bash
git add config/fish/functions/todo.fish config/fish/functions/_todo_usage.fish test/todo_helpers.fish
git commit -m "feat: make todo a dispatcher with add + usage/help"
```

---

### Task 8: `todo edit`

**Files:**
- Modify: `config/fish/functions/todo.fish` (add `edit` case)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
todo edit ccc Reworded task >/dev/null
_todo_read $TODO_FILE
check "edit: text replaced, tag+id kept" (_todo_get_line todo 2) "- [ ] Reworded task @admin (ccc)"
teardown

setup "$SAMPLE"
todo edit ccc New text @newtag >/dev/null
_todo_read $TODO_FILE
check "edit: trailing tag updates tag" (_todo_get_line todo 2) "- [ ] New text @newtag (ccc)"
teardown

setup "$SAMPLE"
check "edit: missing id exits 1" (todo edit zzz nope 2>/dev/null; echo $status) "1"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish edit`
Expected: FAIL (unknown command `edit`).

- [ ] **Step 3: Add the `edit` case** to `todo.fish`'s switch, before `case -h --help`:

```fish
        case edit
            if test (count $rest) -lt 2
                echo "Usage: todo edit <id> <new text>" >&2
                return 1
            end
            if not test -f $file; echo "No todo.md found"; return 1; end
            set -l id $rest[1]
            _todo_read $file; or return 1
            set -l loc (_todo_find_id $id)
            if test -z "$loc"
                echo "todo: no task with id '$id'" >&2
                set -e __td_doing __td_todo __td_archive
                return 1
            end
            set -l p (string split ' ' -- $loc)
            set -l sec $p[1]
            set -l idx $p[2]
            _todo_split (_todo_get_line $sec $idx)
            set -l checked $__td_checked
            set -l tag $__td_tag
            set -l text (string join ' ' $rest[2..-1])
            if string match -qr '@\S+\s*$' -- $text
                set tag (string match -rg '@(\S+)\s*$' -- $text)
                set text (string replace -r '\s*@\S+\s*$' '' -- $text)
            end
            set text (string trim -- $text)
            _todo_set_line $sec $idx (_todo_line $checked $id "$tag" "$text")
            _todo_write $file
            echo "Edited ($id): $text"
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish edit`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/todo.fish test/todo_helpers.fish
git commit -m "feat: add todo edit <id> <text>"
```

---

### Task 9: `todo note`

**Files:**
- Modify: `config/fish/functions/todo.fish` (add `note` case)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
todo note bbb https://example.com/ref >/dev/null
_todo_read $TODO_FILE
check "note: appended indented under task" (_todo_get_line todo 2) "  https://example.com/ref"
check "note: original task intact"         (_todo_get_line todo 1) "- [ ] Backlog one (bbb)"
teardown

setup "$SAMPLE"
todo note ccc second note >/dev/null
_todo_read $TODO_FILE
# ccc already had one context line; the new note lands after it (block end).
check "note: lands at block end" (_todo_get_line todo 3) "  second note"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish note`
Expected: FAIL.

- [ ] **Step 3: Add the `note` case** before `case -h --help`:

```fish
        case note
            if test (count $rest) -lt 2
                echo "Usage: todo note <id> <context text>" >&2
                return 1
            end
            if not test -f $file; echo "No todo.md found"; return 1; end
            set -l id $rest[1]
            _todo_read $file; or return 1
            set -l loc (_todo_find_id $id)
            if test -z "$loc"
                echo "todo: no task with id '$id'" >&2
                set -e __td_doing __td_todo __td_archive
                return 1
            end
            set -l p (string split ' ' -- $loc)
            set -l note (string trim -- (string join ' ' $rest[2..-1]))
            _todo_append_to_block $p[1] $p[2] "  $note"
            _todo_write $file
            echo "Note ($id): $note"
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish note`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/todo.fish test/todo_helpers.fish
git commit -m "feat: add todo note <id> <text>"
```

---

### Task 10: `todo tag`

**Files:**
- Modify: `config/fish/functions/todo.fish` (add `tag` case)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
todo tag bbb backend >/dev/null
_todo_read $TODO_FILE
check "tag: set on untagged task" (_todo_get_line todo 1) "- [ ] Backlog one @backend (bbb)"
teardown

setup "$SAMPLE"
todo tag ccc - >/dev/null
_todo_read $TODO_FILE
check "tag: dash clears tag" (_todo_get_line todo 2) "- [ ] Backlog two (ccc)"
teardown

setup "$SAMPLE"
todo tag bbb @withat >/dev/null
_todo_read $TODO_FILE
check "tag: leading @ accepted" (_todo_get_line todo 1) "- [ ] Backlog one @withat (bbb)"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish tag`
Expected: FAIL.

- [ ] **Step 3: Add the `tag` case** before `case -h --help`:

```fish
        case tag
            if test (count $rest) -ne 2
                echo "Usage: todo tag <id> <tag|->   (- clears the tag)" >&2
                return 1
            end
            if not test -f $file; echo "No todo.md found"; return 1; end
            set -l id $rest[1]
            set -l newtag (string replace -r '^@' '' -- $rest[2])
            test "$newtag" = "-"; and set newtag ''
            _todo_read $file; or return 1
            set -l loc (_todo_find_id $id)
            if test -z "$loc"
                echo "todo: no task with id '$id'" >&2
                set -e __td_doing __td_todo __td_archive
                return 1
            end
            set -l p (string split ' ' -- $loc)
            _todo_split (_todo_get_line $p[1] $p[2])
            _todo_set_line $p[1] $p[2] (_todo_line $__td_checked $id "$newtag" "$__td_text")
            _todo_write $file
            test -n "$newtag"; and echo "Tag ($id): @$newtag"; or echo "Tag ($id): cleared"
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish tag`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/todo.fish test/todo_helpers.fish
git commit -m "feat: add todo tag <id> <tag|->"
```

---

### Task 11: `todo show`

**Files:**
- Modify: `config/fish/functions/todo.fish` (add `show` case)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
set -g _show (todo show ccc)
check "show: line 1 is the task" $_show[1] "- [ ] Backlog two @admin (ccc)"
check "show: line 2 is context"  $_show[2] "  context line for two"
check "show: missing exits 1"    (todo show zzz 2>/dev/null; echo $status) "1"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish show`
Expected: FAIL.

- [ ] **Step 3: Add the `show` case** before `case -h --help`:

```fish
        case show
            if test (count $rest) -ne 1
                echo "Usage: todo show <id>" >&2
                return 1
            end
            if not test -f $file; echo "No todo.md found"; return 1; end
            _todo_read $file; or return 1
            set -l loc (_todo_find_id $rest[1])
            if test -z "$loc"
                echo "todo: no task with id '$rest[1]'" >&2
                set -e __td_doing __td_todo __td_archive
                return 1
            end
            set -l p (string split ' ' -- $loc)
            _todo_get_block $p[1] $p[2]
            set -e __td_doing __td_todo __td_archive
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish show`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/todo.fish test/todo_helpers.fish
git commit -m "feat: add todo show <id>"
```

---

### Task 12: Rewrite `doing` (block-aware + promote by id)

**Files:**
- Modify: `config/fish/functions/doing.fish` (full rewrite)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
# No-arg: promote first incomplete backlog task to bottom of Doing.
setup "$SAMPLE"
doing >/dev/null
_todo_read $TODO_FILE
check "doing: promoted bbb to doing bottom" (_todo_get_line doing 2) "- [ ] Backlog one (bbb)"
check "doing: removed from backlog top"     (_todo_get_line todo 1) "- [ ] Backlog two @admin (ccc)"
teardown

# By id: promote a specific task, carrying its context.
setup "$SAMPLE"
doing ccc >/dev/null
_todo_read $TODO_FILE
check "doing: id-promote task line" (_todo_get_line doing 2) "- [ ] Backlog two @admin (ccc)"
check "doing: id-promote context"   (_todo_get_line doing 3) "  context line for two"
teardown

# Free text: interruption to TOP of Doing.
setup "$SAMPLE"
doing Quick interruption @ops >/dev/null
_todo_read $TODO_FILE
check "doing: interruption on top" (string match -rq '^- \[ \] Quick interruption @ops \([a-z0-9]{3}\)$' -- (_todo_get_line doing 1); and echo yes; or echo no) "yes"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish doing`
Expected: FAIL (old `doing` orphans context, has no id-promote, assigns no id).

- [ ] **Step 3: Rewrite `doing.fish`**

```fish
function doing --description "Start the top backlog task, promote a task by id, or add an interruption to the top of Doing"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end
    if test (count $argv) -eq 1; and contains -- $argv[1] -h --help
        echo "Usage: doing [<id> | <interruption text>]"
        return 0
    end

    _todo_read $file; or return 1

    set -l loc ''
    test (count $argv) -eq 1; and set loc (_todo_find_id $argv[1])

    if test -n "$loc"
        # Promote a specific task by id to the bottom of Doing.
        set -l p (string split ' ' -- $loc)
        set -l block (_todo_take_block $p[1] $p[2])
        set block[1] (string replace -r '^\s*- \[[ xX]\]' '- [ ]' -- $block[1])
        set -a __td_doing $block
        _todo_write $file
        _todo_split $block[1]
        echo "Doing: $__td_text"
        return 0
    end

    if test (count $argv) -gt 0
        # Interruption text: new task at the TOP of Doing.
        set -l text (string join ' ' $argv)
        set -l tag ''
        if string match -qr '@\S+\s*$' -- $text
            set tag (string match -rg '@(\S+)\s*$' -- $text)
            set text (string replace -r '\s*@\S+\s*$' '' -- $text)
        end
        set text (string trim -- $text)
        set __td_doing (_todo_line 0 '' "$tag" "$text") $__td_doing
        _todo_write $file
        echo "Doing: $text"
        return 0
    end

    # No args: promote the first incomplete backlog task to the bottom of Doing.
    set -l idx 0
    for i in (seq (count $__td_todo))
        string match -qr '^\s*- \[[ xX]\]' -- $__td_todo[$i]; or continue
        string match -qr '^\s*- \[x\]' -- $__td_todo[$i]; and continue
        set idx $i
        break
    end
    if test $idx -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No backlog tasks to start"
        return 1
    end
    set -l block (_todo_take_block todo $idx)
    set block[1] (string replace -r '^\s*- \[[ xX]\]' '- [ ]' -- $block[1])
    set -a __td_doing $block
    _todo_write $file
    _todo_split $block[1]
    echo "Doing: $__td_text"
end
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish doing`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/doing.fish test/todo_helpers.fish
git commit -m "feat: rewrite doing — block-aware, promote-by-id, id-assigning"
```

---

### Task 13: Rewrite `done` (block-aware + complete by id)

**Files:**
- Modify: `config/fish/functions/done.fish` (full rewrite)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append. Note `done` ends by calling `next`, so capture only the relevant lines:

```fish
# No-arg: completes the first incomplete Doing task.
setup "$SAMPLE"
done >/dev/null
_todo_read $TODO_FILE
check "done: marked doing task x" (_todo_get_line doing 1) "- [x] First doing task @turbo (aaa)"
teardown

# By id: completes a specific backlog task.
setup "$SAMPLE"
done ccc >/dev/null
_todo_read $TODO_FILE
check "done: id-complete" (_todo_get_line todo 2) "- [x] Backlog two @admin (ccc)"
teardown

setup "$SAMPLE"
check "done: missing id exits 1" (done zzz 2>/dev/null; echo $status) "1"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish done`
Expected: FAIL.

- [ ] **Step 3: Rewrite `done.fish`**

```fish
function done --description "Mark a task done: a specific task by id, the first Doing task, or the next backlog task"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end
    if test (count $argv) -eq 1; and contains -- $argv[1] -h --help
        echo "Usage: done [<id>]"
        return 0
    end

    _todo_read $file; or return 1

    set -l sec ''
    set -l idx 0

    if test (count $argv) -ge 1
        set -l loc (_todo_find_id $argv[1])
        if test -z "$loc"
            echo "todo: no task with id '$argv[1]'" >&2
            set -e __td_doing __td_todo __td_archive
            return 1
        end
        set -l p (string split ' ' -- $loc)
        set sec $p[1]
        set idx $p[2]
    else
        for i in (seq (count $__td_doing))
            string match -qr '^\s*- \[[ xX]\]' -- $__td_doing[$i]; or continue
            string match -qr '^\s*- \[x\]' -- $__td_doing[$i]; and continue
            set sec doing
            set idx $i
            break
        end
        if test $idx -eq 0
            for i in (seq (count $__td_todo))
                string match -qr '^\s*- \[[ xX]\]' -- $__td_todo[$i]; or continue
                string match -qr '^\s*- \[x\]' -- $__td_todo[$i]; and continue
                set sec todo
                set idx $i
                break
            end
        end
    end

    if test $idx -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No tasks to complete"
        return 1
    end

    set -l line (_todo_get_line $sec $idx)
    _todo_set_line $sec $idx (string replace -r '^\s*- \[[ xX]\]' '- [x]' -- $line)
    _todo_write $file
    _todo_split $line
    echo "✓ $__td_text"

    echo ""
    next
    return 0
end
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish done`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/done.fish test/todo_helpers.fish
git commit -m "feat: rewrite done — block-aware, complete-by-id"
```

---

### Task 14: Rewrite `next` (`@tag` filter + IDs in output)

**Files:**
- Modify: `config/fish/functions/next.fish` (full rewrite)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "$SAMPLE"
set -g _n (next 5)
check "next: doing header"    $_n[1] "Doing:"
check "next: doing shows id"  $_n[2] "- First doing task @turbo (aaa)"
teardown

# Tag filter narrows both Doing and backlog to @admin.
setup "$SAMPLE"
set -g _na (next 5 @admin)
check "next: tag filter excludes turbo" (contains -- "- First doing task @turbo (aaa)" $_na; and echo bad; or echo good) "good"
check "next: tag filter includes admin" (contains -- "- Backlog two @admin (ccc)" $_na; and echo yes; or echo no) "yes"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish next`
Expected: FAIL (old `next` strips ids and has no tag filter).

- [ ] **Step 3: Rewrite `next.fish`**

```fish
function next --description "Print the Doing list and the next n backlog tasks (optionally filtered by @tag) from ~/todo.md"
    set -l file (_todo_file)
    set -l n 1
    set -l tag ''
    for a in $argv
        if contains -- $a -h --help
            echo "Usage: next [n] [@tag]"
            return 0
        else if string match -qr '^@.' -- $a
            set tag (string replace '@' '' -- $a)
        else if string match -qr '^[0-9]+$' -- $a
            set n $a
        end
    end

    if not test -f $file
        echo "No todo.md found"
        return 1
    end
    _todo_read $file; or return 1

    set -l doing_out
    set -l i 1
    while test $i -le (count $__td_doing)
        set -l line $__td_doing[$i]
        if not string match -qr '^\s*- \[[ xX]\]' -- $line
            set i (math $i + 1); continue
        end
        if string match -qr '^\s*- \[x\]' -- $line
            set i (math $i + 1); continue
        end
        set -l end (_todo_block_end $i $__td_doing)
        _todo_split $line
        if test -z "$tag"; or test "$__td_tag" = "$tag"
            set -a doing_out (string replace -r '^\s*- \[[ xX]\] ' '- ' -- $line)
            for k in (seq (math $i + 1) $end)
                test -z (string trim -- "$__td_doing[$k]"); and continue
                set -a doing_out $__td_doing[$k]
            end
        end
        set i (math $end + 1)
    end

    set -l todo_out
    set -l cnt 0
    set i 1
    while test $i -le (count $__td_todo); and test $cnt -lt $n
        set -l line $__td_todo[$i]
        if not string match -qr '^\s*- \[[ xX]\]' -- $line
            set i (math $i + 1); continue
        end
        if string match -qr '^\s*- \[x\]' -- $line
            set i (math $i + 1); continue
        end
        set -l end (_todo_block_end $i $__td_todo)
        _todo_split $line
        if test -z "$tag"; or test "$__td_tag" = "$tag"
            set -a todo_out (string replace -r '^\s*- \[[ xX]\] ' '- ' -- $line)
            for k in (seq (math $i + 1) $end)
                test -z (string trim -- "$__td_todo[$k]"); and continue
                set -a todo_out $__td_todo[$k]
            end
            set cnt (math $cnt + 1)
        end
        set i (math $end + 1)
    end

    set -e __td_doing __td_todo __td_archive

    set -l printed false
    if test (count $doing_out) -gt 0
        echo "Doing:"
        printf '%s\n' $doing_out
        set printed true
    end
    if test (count $todo_out) -gt 0
        test $printed = true; and echo ""
        echo "Next:"
        printf '%s\n' $todo_out
        set printed true
    end
    if test $printed = false
        echo "No remaining tasks"
        return 1
    end
end
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish next`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/next.fish test/todo_helpers.fish
git commit -m "feat: rewrite next — @tag filter, ids in output, block-aware"
```

---

### Task 15: Rewrite `archive` on the shared parser

**Files:**
- Modify: `config/fish/functions/archive.fish` (full rewrite)
- Test: `test/todo_helpers.fish`

- [ ] **Step 1: Write failing tests** — append:

```fish
setup "## Doing

- [x] Finished work (aaa)
  some context

# Todo

- [ ] Still open (bbb)

## Archive

- [x] Older (ccc)
"
archive >/dev/null
_todo_read $TODO_FILE
check "archive: completed moved to top of archive" (_todo_get_line archive 1) "- [x] Finished work (aaa)"
check "archive: context moved with it (not orphaned)" (_todo_get_line archive 2) "  some context"
check "archive: existing archive below" (_todo_get_line archive 3) "- [x] Older (ccc)"
check "archive: open task remains in todo" (_todo_get_line todo 1) "- [ ] Still open (bbb)"
check "archive: doing emptied of completed" (count $__td_doing) "0"
teardown

setup "$SAMPLE"
# SAMPLE has no completed tasks outside Archive.
check "archive: nothing to do exits 1" (archive 2>/dev/null; echo $status) "1"
teardown
```

- [ ] **Step 2: Run to verify failure**

Run: `fish test/todo_helpers.fish archive`
Expected: FAIL (old `archive` orphans the `some context` line because it's the indented-only path AND it re-parses independently).

- [ ] **Step 3: Rewrite `archive.fish`**

```fish
function archive --description "Move completed tasks in ~/todo.md to the Archive section"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end
    _todo_read $file; or return 1

    set -l moved
    set -l count 0
    for sec in doing todo
        set -l more true
        while $more
            set more false
            set -l lines
            switch $sec
                case doing
                    set lines $__td_doing
                case todo
                    set lines $__td_todo
            end
            for i in (seq (count $lines))
                if string match -qr '^\s*- \[x\]' -- $lines[$i]
                    set -a moved (_todo_take_block $sec $i)
                    set count (math $count + 1)
                    set more true
                    break
                end
            end
        end
    end

    if test $count -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No completed tasks to archive"
        return 1
    end

    set __td_archive $moved $__td_archive
    _todo_write $file
    echo "Archived $count task"(test $count -gt 1; and echo s)
end
```

- [ ] **Step 4: Run to verify pass**

Run: `fish test/todo_helpers.fish archive`
Expected: all `ok`.

- [ ] **Step 5: Commit**

```bash
git add config/fish/functions/archive.fish test/todo_helpers.fish
git commit -m "feat: rewrite archive on shared block-aware parser (fixes orphaned context)"
```

---

### Task 16: Skill + bootstrap wiring

**Files:**
- Create: `config/claude/skills/todo/SKILL.md`
- Modify: `bootstrap`
- Test: manual (bootstrap is not unit-tested; verify symlinks)

- [ ] **Step 1: Create `config/claude/skills/todo/SKILL.md`**

```markdown
---
name: todo
description: Read and maintain the user's personal todo list (~/todo.md) from the CLI. Use when asked to add, edit, annotate, categorize, complete, or pick up tasks — e.g. "add a todo", "what's next", "pick up the next <category> task", "add context to <task>".
---

# todo — personal task list

The list lives at `~/todo.md` (override with `$TODO_FILE`) and has three
sections: `## Doing`, `# Todo` (backlog), `## Archive`. Each task is a line:

```
- [ ] <text> @<tag> (<id>)
  <indented context line>
```

- `(id)` is a stable 3-char id. Address tasks by id for everything below.
- `@tag` is a single free-form category (a repo name, `admin`, `oncall`, …).
- Indented lines beneath a task are its context (notes, URLs).

## Commands

Run `todo --help` for the authoritative usage. In short:

- `todo add <text> [@tag]` — add a backlog task.
- `todo edit <id> <text>` — replace a task's text (a trailing `@tag` updates the tag).
- `todo note <id> <text>` — append a context line to a task.
- `todo tag <id> <tag|->` — set or clear (`-`) a task's tag.
- `todo show <id>` — print a task and its context.
- `doing` / `doing <id>` / `doing <text>` — promote the top backlog task, promote a specific task, or add an interruption.
- `done` / `done <id>` — complete the current/next task, or a specific one.
- `next [n] [@tag]` — show Doing plus the next n backlog tasks; filter by `@tag`.
- `archive` — move completed tasks to Archive.

## Picking up work by category

To act on the next task in a category, run `next 5 @<tag>` to list candidates,
then read one with `todo show <id>`, add findings with `todo note <id> …`, and
start it with `doing <id>`. Always run `todo show <id>` before editing so you
preserve the existing text, tag, and context.
```

- [ ] **Step 2: Add the skills dir to the `mkdir -p` line in `bootstrap`**

Find the line (near the top) that begins `mkdir -p ~/bin ~/.claude/skills/jira` and append `~/.claude/skills/todo`:

```bash
mkdir -p ~/bin ~/.claude/skills/jira ~/.claude/skills/todo ~/.emacs.d/lisp ~/Library/KeyBindings
```

- [ ] **Step 3: Add `maybe-link` lines in `bootstrap`**

After the existing todo-helper `maybe-link` block (the lines linking `_todo_*`/`todo.fish`), add links for the new helper files, remove the `_todo_strip` link, and add the skill link. The full helper block should be:

```bash
maybe-link config/fish/functions/next.fish ~/.config/fish/functions/next.fish
maybe-link config/fish/functions/done.fish ~/.config/fish/functions/done.fish
maybe-link config/fish/functions/archive.fish ~/.config/fish/functions/archive.fish
maybe-link config/fish/functions/doing.fish ~/.config/fish/functions/doing.fish
maybe-link config/fish/functions/todo.fish ~/.config/fish/functions/todo.fish
maybe-link config/fish/functions/_todo_read.fish ~/.config/fish/functions/_todo_read.fish
maybe-link config/fish/functions/_todo_write.fish ~/.config/fish/functions/_todo_write.fish
maybe-link config/fish/functions/_todo_file.fish ~/.config/fish/functions/_todo_file.fish
maybe-link config/fish/functions/_todo_split.fish ~/.config/fish/functions/_todo_split.fish
maybe-link config/fish/functions/_todo_line.fish ~/.config/fish/functions/_todo_line.fish
maybe-link config/fish/functions/_todo_gen_id.fish ~/.config/fish/functions/_todo_gen_id.fish
maybe-link config/fish/functions/_todo_block_end.fish ~/.config/fish/functions/_todo_block_end.fish
maybe-link config/fish/functions/_todo_canon.fish ~/.config/fish/functions/_todo_canon.fish
maybe-link config/fish/functions/_todo_find_id.fish ~/.config/fish/functions/_todo_find_id.fish
maybe-link config/fish/functions/_todo_get_line.fish ~/.config/fish/functions/_todo_get_line.fish
maybe-link config/fish/functions/_todo_set_line.fish ~/.config/fish/functions/_todo_set_line.fish
maybe-link config/fish/functions/_todo_get_block.fish ~/.config/fish/functions/_todo_get_block.fish
maybe-link config/fish/functions/_todo_take_block.fish ~/.config/fish/functions/_todo_take_block.fish
maybe-link config/fish/functions/_todo_splice.fish ~/.config/fish/functions/_todo_splice.fish
maybe-link config/fish/functions/_todo_append_to_block.fish ~/.config/fish/functions/_todo_append_to_block.fish
maybe-link config/fish/functions/_todo_usage.fish ~/.config/fish/functions/_todo_usage.fish
maybe-link config/claude/skills/todo/SKILL.md ~/.claude/skills/todo/SKILL.md
```

(Also delete the stale `maybe-link config/fish/functions/_todo_strip.fish …` line if present, and remove the dead symlink: `rm -f ~/.config/fish/functions/_todo_strip.fish`.)

- [ ] **Step 4: Run bootstrap and verify links**

Run: `cd ~/.dotfiles; ./bootstrap`
Then: `ls -l ~/.config/fish/functions/_todo_*.fish ~/.claude/skills/todo/SKILL.md`
Expected: every new helper and the skill are symlinks into the repo; `_todo_strip.fish` is gone.

- [ ] **Step 5: Commit**

```bash
git add config/claude/skills/todo/SKILL.md bootstrap
git commit -m "feat: add todo skill and bootstrap symlinks"
```

---

### Task 17: Full-suite run + real-file validation

**Files:** none (validation only)

- [ ] **Step 1: Run the entire test suite**

Run: `fish test/todo_helpers.fish`
Expected: `failed: 0` and exit status 0 (`echo $status` → 0).

- [ ] **Step 2: Dry-run the migration on a COPY of the real file**

```bash
cp ~/todo.md /tmp/todo.before
cp ~/todo.md /tmp/todo.work
TODO_FILE=/tmp/todo.work fish -c 'next 999 >/dev/null; _todo_read /tmp/todo.work; _todo_write /tmp/todo.work'
diff /tmp/todo.before /tmp/todo.work || true
```

Expected diff: only (a) every task line gains a `(id)`, and (b) the flush-left context lines in Doing/Todo become 2-space-indented. No task text or context content should be lost or reordered. **Review this diff carefully.**

- [ ] **Step 3: Back up and migrate the real file**

`~/notes/splash/todo.md` lives in an Obsidian vault and is **not** version-controlled, so keep a plain file backup before the reformat:

```bash
cp ~/todo.md ~/todo.md.bak.$(date +%Y%m%d%H%M%S)
```

Then trigger the in-place canonical rewrite (this is what any mutating command does on first run) and inspect the change against the Step 2 backup:

```bash
fish -c '_todo_read ~/todo.md; _todo_write ~/todo.md'
diff /tmp/todo.before ~/todo.md || true
```

Expected: same shape of diff as Step 2, now applied to the real file. Backfill is complete; all tasks have ids and context is normalized. If anything looks wrong, restore from the `.bak` copy.

- [ ] **Step 4: Smoke-test the live commands**

```bash
fish -c 'next 3'
fish -c 'todo --help'
```

Expected: `next` prints Doing + 3 backlog tasks with ids; `--help` prints the command list.

- [ ] **Step 5: Final commit (if any working-tree changes remain in dotfiles)**

```bash
cd ~/.dotfiles && git status
# nothing to commit if Tasks 1–16 were each committed
```

---

## Self-review notes

- **Spec coverage:** edit (T8), note (T9), tag/category (T7 add-tag, T10), show (T11), move-by-id (T12 doing, T13 done), `@tag` model (T2/T7/T10/T14), random-short-IDs + backfill-all (T3/T5/T17), skill + `--help` (T7/T16), block-aware refactor + archive fold-in (T4/T5/T12–T15), auto-backfill on write (T5/T17). All covered.
- **Type/name consistency:** parsed-line globals `__td_checked/__td_id/__td_tag/__td_text` set by `_todo_split` and read everywhere; section globals `__td_doing/__td_todo/__td_archive`; id pool `__td_ids`. `_todo_line` arg order is `checked id tag text` at every call site. `_todo_find_id` returns `"<section> <idx>"`, split with `string split ' '` by all callers.
- **No placeholders:** every step has complete code or an exact command + expected output.
```
