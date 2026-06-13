function _todo_set_line --description "Replace line idx of a section global (doing/todo/archive)"
    set -l sec $argv[1]
    set -l idx $argv[2]
    set -l line $argv[3]
    switch $sec
        case doing
            set -g __td_doing[$idx] $line
        case todo
            set -g __td_todo[$idx] $line
        case archive
            set -g __td_archive[$idx] $line
    end
end
