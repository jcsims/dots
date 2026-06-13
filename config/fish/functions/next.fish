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
            set -l _drest (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $line)
            set -a doing_out "- $_drest"
            if test $end -gt $i
                for k in (seq (math $i + 1) $end)
                    test -z (string trim -- "$__td_doing[$k]"); and continue
                    set -a doing_out $__td_doing[$k]
                end
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
            set -l _trest (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $line)
            set -a todo_out "- $_trest"
            if test $end -gt $i
                for k in (seq (math $i + 1) $end)
                    test -z (string trim -- "$__td_todo[$k]"); and continue
                    set -a todo_out $__td_todo[$k]
                end
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
