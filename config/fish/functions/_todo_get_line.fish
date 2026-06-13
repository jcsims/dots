function _todo_get_line --description "Echo line idx of a section global (doing/todo/archive)"
    switch $argv[1]
        case doing
            echo $__td_doing[$argv[2]]
        case todo
            echo $__td_todo[$argv[2]]
        case archive
            echo $__td_archive[$argv[2]]
    end
end
