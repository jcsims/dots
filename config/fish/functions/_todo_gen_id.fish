function _todo_gen_id --description "Generate a 3-char base36 id not present in argv (the existing ids)"
    set -l chars a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9
    while true
        set -l id $chars[(random 1 36)]$chars[(random 1 36)]$chars[(random 1 36)]
        if not contains -- $id $argv
            echo $id
            return 0
        end
    end
end
