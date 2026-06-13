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

setup "$SAMPLE"
check "harness: file written" (head -1 $TODO_FILE) "## Doing"
teardown

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

set -g _lines "- [ ] one (aaa)" "  ctx a" "https://x" "- [ ] two (bbb)" "  ctx b"
check "blockend: first block incl flush-left ctx" (_todo_block_end 1 $_lines) "3"
check "blockend: second block to end"             (_todo_block_end 4 $_lines) "5"
set -g _single "- [ ] only (aaa)"
check "blockend: single line block" (_todo_block_end 1 $_single) "1"

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
check "write: ctx indented" $_out[4] "  https://example.com/x"
# The id-less task now has a 3-char id.
check "write: backfilled id" (string match -rq '^- \[ \] Has flush-left ctx \([a-z0-9]{3}\)$' -- $_out[3]; and echo yes; or echo no) "yes"
# The existing id is preserved.
check "write: keeps existing id" (contains -- "- [ ] Already has id (bbb)" $_out; and echo yes; or echo no) "yes"
teardown

# Regression: two adjacent context-free tasks must NOT slurp each other in as
# context. (fish `seq (i+1) i` descends, so a missing guard would duplicate the
# next/own task line as bogus indented context.)
setup "## Doing

# Todo

- [ ] First task
- [ ] Second task

## Archive
"
_todo_read $TODO_FILE
_todo_write $TODO_FILE
set -g _out (cat $TODO_FILE)
check "write: no bogus context line 1" (string match -rq '^- \[ \] First task \([a-z0-9]{3}\)$' -- $_out[5]; and echo yes; or echo no) "yes"
check "write: no bogus context line 2" (string match -rq '^- \[ \] Second task \([a-z0-9]{3}\)$' -- $_out[6]; and echo yes; or echo no) "yes"
check "write: no indented task lines" (string match -q '*  - [*' -- (string join -- '|' $_out); and echo bad; or echo good) "good"
teardown

setup "$SAMPLE"
_todo_read $TODO_FILE
# _todo_read preserves blank lines in section globals.
# Use _todo_find_id results to drive subsequent helpers (index-independent).
set -l _ccc_loc (_todo_find_id ccc)
set -l _aaa_loc (_todo_find_id aaa)
check "find: locates ccc" "$_ccc_loc" "todo 3"
check "find: locates aaa" "$_aaa_loc" "doing 2"
check "find: missing"     (_todo_find_id zzz; and echo found; or echo none) "none"

set -l _ccc_idx (string split ' ' -- $_ccc_loc)[2]
set -l _bbb_loc (_todo_find_id bbb)
set -l _bbb_idx (string split ' ' -- $_bbb_loc)[2]
check "getline: ccc"      (_todo_get_line todo $_ccc_idx) "- [ ] Backlog two @admin (ccc)"

_todo_set_line todo $_bbb_idx "- [ ] Changed (bbb)"
check "setline: applied" $__td_todo[$_bbb_idx] "- [ ] Changed (bbb)"

check "getblock: ccc has ctx" (count (_todo_get_block todo $_ccc_idx)) "3"

_todo_append_to_block todo $_bbb_idx "  a new note"
set -l _note_idx (math $_bbb_idx + 1)
check "append: inserted after block" $__td_todo[$_note_idx] "  a new note"

set -g _taken (_todo_take_block todo $_bbb_idx)
check "take: returned the line" $_taken[1] "- [ ] Changed (bbb)"
# After removing the 2-element block [Changed, a new note], next element at _bbb_idx is ccc.
check "take: removed from section" $__td_todo[$_bbb_idx] "- [ ] Backlog two @admin (ccc)"
teardown

check "splice: mid"  (string join '|' (_todo_splice 1 NEW a b c)) "a|NEW|b|c"
check "splice: end"  (string join '|' (_todo_splice 3 NEW a b c)) "a|b|c|NEW"
check "splice: empty" (_todo_splice 0 NEW) "NEW"

setup "$SAMPLE"
todo add Brand new task >/dev/null
_todo_read $TODO_FILE
# _todo_read keeps blank lines; the real last task is at [-2] ([-1] is a trailing blank).
check "add: appended to todo" (string match -rq '^- \[ \] Brand new task \([a-z0-9]{3}\)$' -- $__td_todo[-2]; and echo yes; or echo no) "yes"
teardown

setup "$SAMPLE"
todo add Tagged item @lender >/dev/null
_todo_read $TODO_FILE
check "add: parses trailing tag" (string match -rq '^- \[ \] Tagged item @lender \([a-z0-9]{3}\)$' -- $__td_todo[-2]; and echo yes; or echo no) "yes"
teardown

setup "$SAMPLE"
check "dispatch: unknown cmd exits 1" (todo bogus 2>/dev/null; echo $status) "1"
check "dispatch: bare todo exits 1"   (todo 2>/dev/null; echo $status) "1"
check "help: mentions add"            (todo --help | string match -q '*todo add*'; and echo yes; or echo no) "yes"
teardown

setup "$SAMPLE"
todo edit ccc Reworded task >/dev/null
_todo_read $TODO_FILE
check "edit: text replaced, tag+id kept" (_todo_get_line todo (_todo_find_id ccc | string split ' ')[2]) "- [ ] Reworded task @admin (ccc)"
teardown

setup "$SAMPLE"
todo edit ccc New text @newtag >/dev/null
_todo_read $TODO_FILE
check "edit: trailing tag updates tag" (_todo_get_line todo (_todo_find_id ccc | string split ' ')[2]) "- [ ] New text @newtag (ccc)"
teardown

setup "$SAMPLE"
check "edit: missing id exits 1" (todo edit zzz nope 2>/dev/null; echo $status) "1"
teardown

setup "$SAMPLE"
todo note bbb https://example.com/ref >/dev/null
_todo_read $TODO_FILE
set -l _bbb_loc (_todo_find_id bbb)
set -l _bbb_idx (string split ' ' -- $_bbb_loc)[2]
set -l _note_idx (math $_bbb_idx + 1)
check "note: appended indented under task" (_todo_get_line todo $_note_idx) "  https://example.com/ref"
check "note: original task intact"         (_todo_get_line todo $_bbb_idx) "- [ ] Backlog one (bbb)"
teardown

setup "$SAMPLE"
todo note ccc "second note" >/dev/null
_todo_read $TODO_FILE
# ccc already had one context line; new note lands after it (block end = idx+2).
set -l _ccc_loc (_todo_find_id ccc)
set -l _ccc_idx (string split ' ' -- $_ccc_loc)[2]
set -l _note2_idx (math $_ccc_idx + 2)
check "note: lands at block end" (_todo_get_line todo $_note2_idx) "  second note"
teardown

setup "$SAMPLE"
todo tag bbb backend >/dev/null
_todo_read $TODO_FILE
check "tag: set on untagged task" (_todo_get_line todo (_todo_find_id bbb | string split ' ')[2]) "- [ ] Backlog one @backend (bbb)"
teardown

setup "$SAMPLE"
todo tag ccc - >/dev/null
_todo_read $TODO_FILE
check "tag: dash clears tag" (_todo_get_line todo (_todo_find_id ccc | string split ' ')[2]) "- [ ] Backlog two (ccc)"
teardown

setup "$SAMPLE"
todo tag bbb @withat >/dev/null
_todo_read $TODO_FILE
check "tag: leading @ accepted" (_todo_get_line todo (_todo_find_id bbb | string split ' ')[2]) "- [ ] Backlog one @withat (bbb)"
teardown

setup "$SAMPLE"
set -g _show (todo show ccc)
check "show: line 1 is the task" $_show[1] "- [ ] Backlog two @admin (ccc)"
check "show: line 2 is context"  $_show[2] "  context line for two"
check "show: missing exits 1"    (todo show zzz 2>/dev/null; echo $status) "1"
teardown

echo ""
echo "passed: $_pass   failed: $_fail"
exit (test $_fail -eq 0; and echo 0; or echo 1)
