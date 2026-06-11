function _todo_read --description "Partition a todo file into __td_doing/__td_todo/__td_archive globals; return 1 on unexpected structure"
    set -l file $argv[1]

    set -g __td_doing
    set -g __td_todo
    set -g __td_archive

    set -l section preamble
    set -l pre

    for line in (cat $file)
        if string match -qr '^#+\s' -- $line
            set -l name (string lower (string trim (string replace -r '^#+\s+' '' -- $line)))
            switch $name
                case doing
                    set section doing
                case todo 'to do'
                    set section todo
                case archive
                    set section archive
                case '*'
                    echo "todo: unexpected header '$line' in $file" >&2
                    return 1
            end
            continue
        end

        switch $section
            case preamble
                set -a pre $line
            case doing
                set -a __td_doing $line
            case todo
                set -a __td_todo $line
            case archive
                set -a __td_archive $line
        end
    end

    # Any non-blank content before the first header means the file isn't shaped
    # the way we expect; refuse rather than risk losing it.
    for l in $pre
        if test -n "$l"
            echo "todo: unexpected content before first header in $file" >&2
            return 1
        end
    end

    return 0
end
