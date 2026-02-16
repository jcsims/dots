function next --description "Print the next incomplete task from ~/todo.md"
    set -l file ~/todo.md
    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    set -l found false
    set -l lines (cat $file)

    for i in (seq (count $lines))
        set -l line $lines[$i]

        # Skip completed tasks
        echo $line | string match -qr '^\s*- \[x\]' && continue

        # Match incomplete task lines
        if echo $line | string match -qr '^\s*- (\[ \] )?[^\[]'
            # Print the task line, stripping the checkbox if present
            echo $line | string replace -r '^\s*- (\[ \] )?' -- '- '
            set found true

            # Print any following indented context lines
            set -l j (math $i + 1)
            while test $j -le (count $lines)
                set -l next_line $lines[$j]
                # Context lines are indented and not a new task
                if echo $next_line | string match -qr '^\s+[^-]'
                    echo $next_line
                else
                    break
                end
                set j (math $j + 1)
            end
            break
        end
    end

    if not $found
        echo "No remaining tasks"
        return 1
    end
end
