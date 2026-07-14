#!/usr/bin/env bats

setup() {
    export DAILY_DIR="$BATS_TEST_TMPDIR/daily"
    PATH="$BATS_TEST_DIRNAME/../bin:$PATH"
    TODAY=$(date +%F)
    NOTE="$DAILY_DIR/$TODAY.org"
}

@test "path prints today's path and creates the file with an org-roam header" {
    run daily-note path
    [ "$status" -eq 0 ]
    [ "$output" = "$NOTE" ]
    [ -f "$NOTE" ]

    mapfile -t lines <"$NOTE"
    [ "${lines[0]}" = ":PROPERTIES:" ]
    [[ "${lines[1]}" =~ ^:ID:\ +[0-9A-Fa-f-]+$ ]]
    [ "${lines[2]}" = ":END:" ]
    [ "${lines[3]}" = "#+title: $TODAY" ]
    [ "${#lines[@]}" -eq 4 ]
}

@test "path is idempotent (does not regenerate the ID)" {
    daily-note path
    id1=$(sed -n 2p "$NOTE")
    daily-note path
    id2=$(sed -n 2p "$NOTE")
    [ "$id1" = "$id2" ]
}

@test "no arguments prints usage and exits non-zero" {
    run daily-note
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "append creates the section and entry" {
    run bash -c "daily-note append --section Tasks --key K1 --heading 'TODO K1 Buy milk' </dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "added: K1" ]

    expected="* Tasks
** TODO K1 Buy milk"
    [ "$(tail -n 2 "$NOTE")" = "$expected" ]
}

@test "append includes body from stdin" {
    printf 'line one\nline two\n' |
        daily-note append --section Tasks --key K1 --heading 'TODO K1 Buy milk'

    expected="* Tasks
** TODO K1 Buy milk
line one
line two"
    [ "$(tail -n 4 "$NOTE")" = "$expected" ]
}

@test "append adds to the end of an existing section, before the next section" {
    daily-note append --section Tasks --key K1 --heading 'TODO K1 First' </dev/null
    daily-note append --section Slack --key S1 --heading 'S1 Slack thing' </dev/null
    daily-note append --section Tasks --key K2 --heading 'TODO K2 Second' </dev/null

    expected="* Tasks
** TODO K1 First
** TODO K2 Second
* Slack
** S1 Slack thing"
    [ "$(tail -n 5 "$NOTE")" = "$expected" ]
}

@test "append dedupes by key" {
    daily-note append --section Tasks --key K1 --heading 'TODO K1 Buy milk' </dev/null
    run bash -c "daily-note append --section Tasks --key K1 --heading 'TODO K1 Buy milk' </dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "skipped: K1" ]
    [ "$(grep -c 'TODO K1 Buy milk' "$NOTE")" -eq 1 ]
}

@test "append with missing flags prints usage" {
    run bash -c "daily-note append --section Tasks </dev/null"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]]
}

@test "append dedupes the second distinct key too" {
    daily-note append --section Tasks --key K1 --heading 'TODO K1 first' </dev/null
    daily-note append --section Tasks --key K2 --heading 'TODO K2 second' </dev/null
    run bash -c "daily-note append --section Tasks --key K2 --heading 'TODO K2 second' </dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "skipped: K2" ]
    [ "$(grep -c 'TODO K2 second' "$NOTE")" -eq 1 ]
}

@test "append escapes body lines that look like org headings" {
    printf '* a starred bullet\nplain line\n' |
        daily-note append --section Tasks --key K1 --heading 'TODO K1 Buy milk'
    daily-note append --section Tasks --key K2 --heading 'TODO K2 Second' </dev/null

    expected="* Tasks
** TODO K1 Buy milk
 * a starred bullet
plain line
** TODO K2 Second"
    [ "$(tail -n 5 "$NOTE")" = "$expected" ]
}

@test "append rejects an entry that does not contain its key" {
    run bash -c "daily-note append --section Tasks --key NOWHERE --heading 'TODO Buy milk' </dev/null"
    [ "$status" -eq 2 ]
    [[ "$output" == *"key not in entry"* ]]
    [ ! -e "$NOTE" ] || ! grep -qF 'TODO Buy milk' "$NOTE"
}

@test "append with a flag missing its value prints usage" {
    run bash -c "daily-note append --section Tasks --key </dev/null"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage"* ]]
}

@test "append handles URL-shaped keys" {
    url="https://splash.slack.com/archives/C123/p999"
    run bash -c "daily-note append --section Slack --key '$url' --heading '[[$url][#chan: topic]]' </dev/null"
    [ "$status" -eq 0 ]
    [ "$output" = "added: $url" ]
    run bash -c "daily-note append --section Slack --key '$url' --heading '[[$url][#chan: topic]]' </dev/null"
    [ "$output" = "skipped: $url" ]
}
