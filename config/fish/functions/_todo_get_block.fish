function _todo_get_block --description "Echo the task block at idx in a section global, non-destructively"
    set -l sec $argv[1]
    set -l idx $argv[2]
    switch $sec
        case doing
            printf '%s\n' $__td_doing[$idx..(_todo_block_end $idx $__td_doing)]
        case todo
            printf '%s\n' $__td_todo[$idx..(_todo_block_end $idx $__td_todo)]
        case archive
            printf '%s\n' $__td_archive[$idx..(_todo_block_end $idx $__td_archive)]
    end
end
