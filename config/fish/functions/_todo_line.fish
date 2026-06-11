function _todo_line --description "Build a canonical task line from checked/id/tag/text"
    set -l checked $argv[1]
    set -l id $argv[2]
    set -l tag $argv[3]
    set -l text $argv[4]

    set -l box '[ ]'
    test "$checked" = 1; and set box '[x]'

    set -l out "- $box $text"
    test -n "$tag"; and set out "$out @$tag"
    test -n "$id"; and set out "$out ($id)"
    echo $out
end
