function _todo_splice --description "Echo args[3..] with <line> inserted after position idx. Usage: _todo_splice <idx> <line> <arr...>"
    set -l idx $argv[1]
    set -l line $argv[2]
    set -l arr $argv[3..-1]
    set -l n (count $arr)
    if test $n -eq 0
        echo $line
        return
    end
    for i in (seq $n)
        echo $arr[$i]
        test $i -eq $idx; and echo $line
    end
end
