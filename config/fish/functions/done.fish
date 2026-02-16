function done --description "Mark the next incomplete task in ~/todo.md as done"
    set -l file ~/todo.md
    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    set -l lines (cat $file)
    set -l found false

    for i in (seq (count $lines))
        set -l line $lines[$i]

        # Skip completed tasks
        echo $line | string match -qr '^\s*- \[x\]' && continue

        # Match incomplete task lines
        if echo $line | string match -qr '^\s*- (\[ \] )?[^\[]'
            set found true

            # Mark as done: convert to checked checkbox
            set lines[$i] (echo $line | string replace -r '^\s*- (\[ \] )?' -- '- [x] ')

            # Print what we completed
            echo "✓ "(echo $line | string replace -r '^\s*- (\[ \] )?' -- '')
            break
        end
    end

    if not $found
        echo "No remaining tasks"
        return 1
    end

    printf '%s\n' $lines >$file

    # Show the next task
    echo ""
    echo "Next:"
    next
end
