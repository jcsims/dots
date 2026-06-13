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
        echo "No completed tasks to archive" >&2
        return 1
    end

    set __td_archive $moved $__td_archive
    _todo_write $file
    echo "Archived $count task"(test $count -gt 1; and echo s)
end
