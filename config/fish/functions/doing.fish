function doing --description "Start the top backlog task, or add an interruption task to the top of Doing"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    _todo_read $file; or return 1

    # With text: interruption work goes to the TOP of Doing (what you're on now).
    if test (count $argv) -gt 0
        set -l text (string join ' ' $argv)
        set __td_doing "- [ ] $text" $__td_doing
        _todo_write $file
        echo "Doing: $text"
        return 0
    end

    # No args: promote the first incomplete backlog task to the BOTTOM of Doing.
    set -l idx 0
    if test (count $__td_todo) -ge 1
        for i in (seq (count $__td_todo))
            string match -qr '^\s*- \[x\]' -- $__td_todo[$i]; and continue
            if string match -qr '^\s*- (\[ \] )?[^\[]' -- $__td_todo[$i]
                set idx $i
                break
            end
        end
    end

    if test $idx -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No backlog tasks to start"
        return 1
    end

    # Grab the task line plus any indented context lines that follow it.
    set -l endi $idx
    set -l k (math $idx + 1)
    while test $k -le (count $__td_todo); and string match -qr '^\s+[^-]' -- $__td_todo[$k]
        set endi $k
        set k (math $k + 1)
    end

    set -l block $__td_todo[$idx..$endi]
    set block[1] (string replace -r '^\s*- (\[ \] )?' -- '- [ ] ' $block[1])
    set -l label (string replace -r '^\s*- (\[ \] )?' -- '' $__td_todo[$idx])

    set -e __td_todo[$idx..$endi]
    set -a __td_doing $block

    _todo_write $file
    echo "Doing: $label"
end
