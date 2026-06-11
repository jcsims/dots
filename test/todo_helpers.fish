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

echo ""
echo "passed: $_pass   failed: $_fail"
exit (test $_fail -eq 0; and echo 0; or echo 1)
