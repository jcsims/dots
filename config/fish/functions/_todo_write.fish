function _todo_write --description "Write the __td_doing/__td_todo/__td_archive globals back to a todo file in canonical form"
    set -l file $argv[1]

    set -l out
    set -a out "## Doing"
    set -l b (_todo_strip $__td_doing)
    test (count $b) -gt 0; and set -a out "" $b

    set -a out "" "# Todo"
    set b (_todo_strip $__td_todo)
    test (count $b) -gt 0; and set -a out "" $b

    set -a out "" "## Archive"
    set b (_todo_strip $__td_archive)
    test (count $b) -gt 0; and set -a out "" $b

    printf '%s\n' $out >$file

    set -e __td_doing __td_todo __td_archive
end
