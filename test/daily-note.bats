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
