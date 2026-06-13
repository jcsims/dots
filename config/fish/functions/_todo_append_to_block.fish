function _todo_append_to_block --description "Insert a line at the end of the task block at idx in a section global"
    set -l sec $argv[1]
    set -l idx $argv[2]
    set -l line $argv[3]
    switch $sec
        case doing
            set -g __td_doing (_todo_splice (_todo_block_end $idx $__td_doing) "$line" $__td_doing)
        case todo
            set -g __td_todo (_todo_splice (_todo_block_end $idx $__td_todo) "$line" $__td_todo)
        case archive
            set -g __td_archive (_todo_splice (_todo_block_end $idx $__td_archive) "$line" $__td_archive)
    end
end
