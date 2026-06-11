function next --description "Print the Doing list and the next n backlog tasks from ~/todo.md"
    set -l file ~/todo.md
    set -l n 1
    if test (count $argv) -gt 0
        set n $argv[1]
    end

    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    _todo_read $file; or return 1

    # Collect every incomplete Doing task (with its context lines).
    set -l doing_out
    set -l i 1
    while test $i -le (count $__td_doing)
        set -l line $__td_doing[$i]
        if string match -qr '^\s*- \[x\]' -- $line
            set i (math $i + 1)
            continue
        end
        if string match -qr '^\s*- (\[ \] )?[^\[]' -- $line
            set -a doing_out (string replace -r '^\s*- (\[ \] )?' -- '- ' $line)
            set i (math $i + 1)
            while test $i -le (count $__td_doing); and string match -qr '^\s+[^-]' -- $__td_doing[$i]
                set -a doing_out $__td_doing[$i]
                set i (math $i + 1)
            end
            continue
        end
        set i (math $i + 1)
    end

    # Collect the top n incomplete backlog tasks (with their context lines).
    set -l todo_out
    set -l cnt 0
    set i 1
    while test $i -le (count $__td_todo); and test $cnt -lt $n
        set -l line $__td_todo[$i]
        if string match -qr '^\s*- \[x\]' -- $line
            set i (math $i + 1)
            continue
        end
        if string match -qr '^\s*- (\[ \] )?[^\[]' -- $line
            set -a todo_out (string replace -r '^\s*- (\[ \] )?' -- '- ' $line)
            set cnt (math $cnt + 1)
            set i (math $i + 1)
            while test $i -le (count $__td_todo); and string match -qr '^\s+[^-]' -- $__td_todo[$i]
                set -a todo_out $__td_todo[$i]
                set i (math $i + 1)
            end
            continue
        end
        set i (math $i + 1)
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
