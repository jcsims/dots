function next --description "Print the next n incomplete tasks from ~/todo.md"
    set -l file ~/todo.md
    set -l n 1
    if test (count $argv) -gt 0
        set n $argv[1]
    end

    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    set -l task_count 0
    set -l lines (cat $file)

    for i in (seq (count $lines))
        set -l line $lines[$i]

        # Skip completed tasks
        echo $line | string match -qr '^\s*- \[x\]' && continue

        # Match incomplete task lines
        if echo $line | string match -qr '^\s*- (\[ \] )?[^\[]'
            # Print the task line, stripping the checkbox if present
            echo $line | string replace -r '^\s*- (\[ \] )?' -- '- '
            set task_count (math $task_count + 1)

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

            test $task_count -ge $n; and break
        end
    end

    if test $task_count -eq 0
        echo "No remaining tasks"
        return 1
    end
end
