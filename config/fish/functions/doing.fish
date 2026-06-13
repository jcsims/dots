function doing --description "Start the top backlog task, promote a task by id, or add an interruption to the top of Doing"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end
    if test (count $argv) -eq 1; and contains -- $argv[1] -h --help
        echo "Usage: doing [<id> | <interruption text>]"
        return 0
    end

    _todo_read $file; or return 1

    set -l loc ''
    test (count $argv) -eq 1; and set loc (_todo_find_id $argv[1])

    if test -n "$loc"
        # Promote a specific task by id to the bottom of Doing.
        set -l p (string split ' ' -- $loc)
        set -l block (_todo_take_block $p[1] $p[2])
        set -l _rest (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $block[1])
        set block[1] "- [ ] $_rest"
        set -a __td_doing $block
        _todo_write $file
        _todo_split $block[1]
        echo "Doing: $__td_text"
        return 0
    end

    if test (count $argv) -gt 0
        # Interruption text: new task at the TOP of Doing.
        set -l text (string join ' ' $argv)
        set -l tag ''
        if string match -qr '@\S+\s*$' -- $text
            set tag (string match -rg '@(\S+)\s*$' -- $text)
            set text (string replace -r '\s*@\S+\s*$' '' -- $text)
        end
        set text (string trim -- $text)
        set __td_doing (_todo_line 0 '' "$tag" "$text") $__td_doing
        _todo_write $file
        echo "Doing: $text"
        return 0
    end

    # No args: promote the first incomplete backlog task to the bottom of Doing.
    set -l idx 0
    for i in (seq (count $__td_todo))
        string match -qr '^\s*- \[[ xX]\]' -- $__td_todo[$i]; or continue
        string match -qr '^\s*- \[x\]' -- $__td_todo[$i]; and continue
        set idx $i
        break
    end
    if test $idx -eq 0
        set -e __td_doing __td_todo __td_archive
        echo "No backlog tasks to start"
        return 1
    end
    set -l block (_todo_take_block todo $idx)
    set -l _rest (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $block[1])
    set block[1] "- [ ] $_rest"
    set -a __td_doing $block
    _todo_write $file
    _todo_split $block[1]
    echo "Doing: $__td_text"
end
