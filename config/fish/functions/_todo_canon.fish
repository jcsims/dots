function _todo_canon --description "Echo canonical task-block lines for a section. Assigns ids using/extending the global __td_ids pool; normalizes context to 2-space indent."
    set -l lines $argv
    set -l n (count $lines)
    set -l out
    set -l i 1
    while test $i -le $n
        set -l line $lines[$i]
        if test -z (string trim -- "$line")
            set i (math $i + 1)
            continue
        end
        if string match -qr '^\s*- \[[ xX]\]' -- $line
            _todo_split $line
            set -l id $__td_id
            test -z "$id"; and set id (_todo_gen_id $__td_ids)
            set -a __td_ids $id
            set -a out (_todo_line $__td_checked $id "$__td_tag" "$__td_text")

            set -l end (_todo_block_end $i $lines)
            for k in (seq (math $i + 1) $end)
                set -l c $lines[$k]
                test -z (string trim -- "$c"); and continue
                set -a out "  "(string trim -- "$c")
            end
            set i (math $end + 1)
        else
            # Should not occur after _todo_read's guard; preserve to avoid data loss.
            set -a out $line
            set i (math $i + 1)
        end
    end
    test (count $out) -gt 0; and printf '%s\n' $out
end
