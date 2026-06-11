function _todo_file --description "Resolve the todo file path (TODO_FILE override, else ~/todo.md)"
    if set -q TODO_FILE; and test -n "$TODO_FILE"
        echo $TODO_FILE
    else
        echo ~/todo.md
    end
end
