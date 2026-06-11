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

echo ""
echo "passed: $_pass   failed: $_fail"
exit (test $_fail -eq 0; and echo 0; or echo 1)
