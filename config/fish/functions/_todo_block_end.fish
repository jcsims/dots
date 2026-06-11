function _todo_block_end --description "Index of the last line of the task block starting at idx. Usage: _todo_block_end <idx> <lines...>"
    set -l idx $argv[1]
    set -l lines $argv[2..-1]
    set -l n (count $lines)

    set -l endi $idx
    set -l k (math $idx + 1)
    while test $k -le $n
        if string match -qr '^\s*- \[[ xX]\]' -- $lines[$k]
            break
        end
        set endi $k
        set k (math $k + 1)
    end
    echo $endi
end
