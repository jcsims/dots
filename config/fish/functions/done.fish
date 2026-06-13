function done --description "Mark a task done: a specific task by id, the first Doing task, or the next backlog task"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end
    if test (count $argv) -eq 1; and contains -- $argv[1] -h --help
        echo "Usage: done [<id>]"
        return 0
    end

    _todo_read $file; or return 1

    set -l sec ''
    set -l idx 0

    if test (count $argv) -ge 1
        set -l loc (_todo_find_id $argv[1])
        if test -z "$loc"
            echo "todo: no task with id '$argv[1]'" >&2
            set -e __td_doing __td_todo __td_archive
            return 1
        end
        set -l p (string split ' ' -- $loc)
        set sec $p[1]
        set idx $p[2]
    else
        for i in (seq (count $__td_doing))
            string match -qr '^\s*- \[[ xX]\]' -- $__td_doing[$i]; or continue
            string match -qr '^\s*- \[x\]' -- $__td_doing[$i]; and continue
            set sec doing
            set idx $i
            break
        end
        if test $idx -eq 0
            for i in (seq (count $__td_todo))
                string match -qr '^\s*- \[[ xX]\]' -- $__td_todo[$i]; or continue
                string match -qr '^\s*- \[x\]' -- $__td_todo[$i]; and continue
                set sec todo
                set idx $i
                break
            end
        end
    end

    if test $idx -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No tasks to complete"
        return 1
    end

    set -l line (_todo_get_line $sec $idx)
    set -l _rest (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $line)
    _todo_set_line $sec $idx "- [x] $_rest"
    _todo_write $file
    _todo_split $line
    echo "✓ $__td_text"

    echo ""
    next
    return 0
end
