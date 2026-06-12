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
