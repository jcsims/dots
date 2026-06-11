function _todo_strip --description "Echo the given lines with blank lines removed"
    set -l out
    for l in $argv
        set -l t (string trim -- "$l")
        test -n "$t"; and set -a out $l
    end
    test (count $out) -gt 0; and printf '%s\n' $out
end
