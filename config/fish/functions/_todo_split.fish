function _todo_split --description "Parse a task line into globals __td_checked/__td_id/__td_tag/__td_text"
    set -l line $argv[1]

    set -g __td_checked 0
    string match -qr '^\s*- \[x\]' -- $line; and set -g __td_checked 1

    set -l body (string replace -r '^\s*- \[[ xX]\]\s*' '' -- $line)

    set -g __td_id ''
    if string match -qr '\([a-z0-9]{3}\)\s*$' -- $body
        set -g __td_id (string match -rg '\(([a-z0-9]{3})\)\s*$' -- $body)
        set body (string replace -r '\s*\([a-z0-9]{3}\)\s*$' '' -- $body)
    end

    set -g __td_tag ''
    if string match -qr '@\S+\s*$' -- $body
        set -g __td_tag (string match -rg '@(\S+)\s*$' -- $body)
        set body (string replace -r '\s*@\S+\s*$' '' -- $body)
    end

    set -g __td_text (string trim -- $body)
end
