function todo --description "Add a task to the backlog (the # Todo section) in ~/todo.md"
    set -l file (_todo_file)
    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    if test (count $argv) -eq 0
        echo "Usage: todo <task text>"
        return 1
    end

    _todo_read $file; or return 1

    set -l text (string join ' ' $argv)
    set -a __td_todo "- [ ] $text"

    _todo_write $file
    echo "Todo: $text"
end
