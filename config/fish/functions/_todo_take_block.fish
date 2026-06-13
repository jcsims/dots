function _todo_take_block --description "Remove and echo the task block at idx in a section global"
    set -l sec $argv[1]
    set -l idx $argv[2]
    switch $sec
        case doing
            set -l end (_todo_block_end $idx $__td_doing)
            printf '%s\n' $__td_doing[$idx..$end]
            set -e __td_doing[$idx..$end]
        case todo
            set -l end (_todo_block_end $idx $__td_todo)
            printf '%s\n' $__td_todo[$idx..$end]
            set -e __td_todo[$idx..$end]
        case archive
            set -l end (_todo_block_end $idx $__td_archive)
            printf '%s\n' $__td_archive[$idx..$end]
            set -e __td_archive[$idx..$end]
    end
end
