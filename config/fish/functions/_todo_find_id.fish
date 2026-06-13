function _todo_find_id --description "Find a task by id across loaded sections; echoes 'section idx' or returns 1"
    set -l want $argv[1]
    for section in doing todo archive
        set -l lines
        switch $section
            case doing
                set lines $__td_doing
            case todo
                set lines $__td_todo
            case archive
                set lines $__td_archive
        end
        for i in (seq (count $lines))
            string match -qr '^\s*- \[[ xX]\]' -- $lines[$i]; or continue
            _todo_split $lines[$i]
            if test "$__td_id" = "$want"
                echo "$section $i"
                return 0
            end
        end
    end
    return 1
end
