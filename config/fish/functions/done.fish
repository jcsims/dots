function done --description "Mark the first Doing task (or next backlog task) in ~/todo.md as done"
    set -l file ~/todo.md
    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    _todo_read $file; or return 1

    # Prefer finishing active work: the first incomplete Doing task, then fall
    # back to the top of the backlog.
    set -l target
    set -l idx 0

    set -l i 1
    while test $i -le (count $__td_doing)
        if string match -qr '^\s*- \[x\]' -- $__td_doing[$i]
            set i (math $i + 1)
            continue
        end
        if string match -qr '^\s*- (\[ \] )?[^\[]' -- $__td_doing[$i]
            set target doing
            set idx $i
            break
        end
        set i (math $i + 1)
    end

    if test $idx -eq 0
        set i 1
        while test $i -le (count $__td_todo)
            if string match -qr '^\s*- \[x\]' -- $__td_todo[$i]
                set i (math $i + 1)
                continue
            end
            if string match -qr '^\s*- (\[ \] )?[^\[]' -- $__td_todo[$i]
                set target todo
                set idx $i
                break
            end
            set i (math $i + 1)
        end
    end

    if test $idx -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No tasks to complete"
        return 1
    end

    if test $target = doing
        set -l line $__td_doing[$idx]
        set __td_doing[$idx] (string replace -r '^\s*- (\[ \] )?' -- '- [x] ' $line)
        echo "✓ "(string replace -r '^\s*- (\[ \] )?' -- '' $line)
    else
        set -l line $__td_todo[$idx]
        set __td_todo[$idx] (string replace -r '^\s*- (\[ \] )?' -- '- [x] ' $line)
        echo "✓ "(string replace -r '^\s*- (\[ \] )?' -- '' $line)
    end

    _todo_write $file

    echo ""
    next
    return 0
end
