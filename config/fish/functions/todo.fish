function todo --description "Manage ~/todo.md: add/edit/note/tag/show tasks. Run 'todo --help'."
    set -l file (_todo_file)

    if test (count $argv) -eq 0
        _todo_usage >&2
        return 1
    end

    set -l cmd $argv[1]
    set -l rest $argv[2..-1]

    switch $cmd
        case add
            if test (count $rest) -eq 0
                echo "Usage: todo add <task text> [@tag]" >&2
                return 1
            end
            if not test -f $file
                echo "No todo.md found"
                return 1
            end
            _todo_read $file; or return 1
            set -l text (string join ' ' -- $rest)
            set -l tag ''
            if string match -qr '@\S+\s*$' -- $text
                set tag (string match -rg '@(\S+)\s*$' -- $text)
                set text (string replace -r '\s*@\S+\s*$' '' -- $text)
            end
            set text (string trim -- $text)
            set -a __td_todo (_todo_line 0 '' "$tag" "$text")
            _todo_write $file
            test -n "$tag"; and echo "Todo: $text @$tag"; or echo "Todo: $text"

        case edit
            if test (count $rest) -lt 2
                echo "Usage: todo edit <id> <new text>" >&2
                return 1
            end
            if not test -f $file; echo "No todo.md found"; return 1; end
            set -l id $rest[1]
            _todo_read $file; or return 1
            set -l loc (_todo_find_id $id)
            if test -z "$loc"
                echo "todo: no task with id '$id'" >&2
                set -e __td_doing __td_todo __td_archive
                return 1
            end
            set -l p (string split ' ' -- $loc)
            set -l sec $p[1]
            set -l idx $p[2]
            _todo_split (_todo_get_line $sec $idx)
            set -l checked $__td_checked
            set -l tag $__td_tag
            set -l text (string join ' ' -- $rest[2..-1])
            if string match -qr '@\S+\s*$' -- $text
                set tag (string match -rg '@(\S+)\s*$' -- $text)
                set text (string replace -r '\s*@\S+\s*$' '' -- $text)
            end
            set text (string trim -- $text)
            _todo_set_line $sec $idx (_todo_line $checked $id "$tag" "$text")
            _todo_write $file
            echo "Edited ($id): $text"

        case note
            if test (count $rest) -lt 2
                echo "Usage: todo note <id> <context text>" >&2
                return 1
            end
            if not test -f $file; echo "No todo.md found"; return 1; end
            set -l id $rest[1]
            _todo_read $file; or return 1
            set -l loc (_todo_find_id $id)
            if test -z "$loc"
                echo "todo: no task with id '$id'" >&2
                set -e __td_doing __td_todo __td_archive
                return 1
            end
            set -l p (string split ' ' -- $loc)
            set -l note (string trim -- (string join ' ' -- $rest[2..-1]))
            _todo_append_to_block $p[1] $p[2] "  $note"
            _todo_write $file
            echo "Note ($id): $note"

        case -h --help
            _todo_usage

        case '*'
            echo "todo: unknown command '$cmd'" >&2
            _todo_usage >&2
            return 1
    end
end
