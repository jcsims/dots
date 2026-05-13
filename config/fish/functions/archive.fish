function archive --description "Move completed tasks in ~/todo.md to the Archive header"
    set -l file ~/todo.md
    if not test -f $file
        echo "No todo.md found"
        return 1
    end

    set -l lines (cat $file)
    set -l kept
    set -l completed
    set -l archive_lines
    set -l in_archive false
    set -l count 0

    # Split into: pre-archive content, and existing archive content
    for i in (seq (count $lines))
        set -l line $lines[$i]

        if echo $line | string match -qr '^##?\s+Archive'
            set in_archive true
            continue
        end

        if $in_archive
            set -a archive_lines $line
        else
            set -a kept $line
        end
    end

    # Extract completed tasks (and their context lines) from kept lines
    set -l new_kept
    set -l i 1
    while test $i -le (count $kept)
        set -l line $kept[$i]

        if echo $line | string match -qr '^\s*- \[x\]'
            set -a completed $line
            set count (math $count + 1)

            # Grab any indented context lines that follow
            set i (math $i + 1)
            while test $i -le (count $kept)
                if echo $kept[$i] | string match -qr '^\s+[^-]'
                    set -a completed $kept[$i]
                else
                    break
                end
                set i (math $i + 1)
            end
        else
            set -a new_kept $line
            set i (math $i + 1)
        end
    end

    if test $count -eq 0
        echo "No completed tasks to archive"
        return 1
    end

    # Strip trailing blank lines from new_kept
    while test (count $new_kept) -gt 0; and test -z "$new_kept[-1]"
        set -e new_kept[-1]
    end

    # Strip leading blank lines from archive_lines (the header's blank line is re-added below)
    while test (count $archive_lines) -gt 0; and test -z "$archive_lines[1]"
        set -e archive_lines[1]
    end

    # Build output: kept content, then archive section with new items on top
    set -l output $new_kept
    set -a output ""
    set -a output "## Archive"
    set -a output ""

    # Newly completed tasks go first
    for line in $completed
        set -a output $line
    end

    # Then existing archive content
    for line in $archive_lines
        set -a output $line
    end

    printf '%s\n' $output >$file
    echo "Archived $count task"(test $count -gt 1; and echo "s"; or echo "")
end
