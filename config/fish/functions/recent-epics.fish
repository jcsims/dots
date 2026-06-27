#!/usr/bin/env fish

function recent-epics -d "List recently-updated RENG Jira epics (Done first), with links"
    set -l days $argv[1]
    test -z "$days"; and set days 18

    set -l base "https://splashfinancial.atlassian.net/browse"

    set -l rows (jira issue list -p RENG -tEpic \
        -q "updated >= -$days"d"" \
        --order-by updated \
        --plain --no-headers --columns key,status,summary 2>/dev/null)

    echo "RENG epics updated in the last $days days:"
    echo

    # Print Done epics first, then everything else; preserve the updated-desc
    # order returned by Jira within each group.
    for pass in done other
        for row in $rows
            set -l fields (string split \t -- $row | string trim | string match -v '')
            set -l key $fields[1]
            set -l state $fields[2]
            set -l summary (string join ' ' $fields[3..-1])

            if test "$pass" = done; and test "$state" != Done
                continue
            end
            if test "$pass" = other; and test "$state" = Done
                continue
            end

            printf '- [%s] %s\n  %s/%s\n' $state $summary $base $key
        end
    end
end
