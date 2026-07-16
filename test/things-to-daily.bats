#!/usr/bin/env bats

setup() {
    export DAILY_DIR="$BATS_TEST_TMPDIR/daily"
    export FIXTURES="$BATS_TEST_TMPDIR/fixtures"
    export THINGS_LOG="$BATS_TEST_TMPDIR/things.log"
    STUB_DIR="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$FIXTURES" "$STUB_DIR"

    # Stub `things`: list serves fixture JSON per view; complete logs the call.
    cat >"$STUB_DIR/things" <<'EOF'
#!/usr/bin/env bash
case "$1" in
    list)
        view="$2"
        case "$*" in
            *--area*) f="$FIXTURES/$view-area.json" ;;
            *--tag*)  f="$FIXTURES/$view-tag.json" ;;
            *)        f="" ;;
        esac
        if [ -n "$f" ] && [ -f "$f" ]; then cat "$f"; else echo null; fi
        ;;
    complete)
        echo "complete $2" >>"$THINGS_LOG"
        exit "${THINGS_COMPLETE_EXIT:-0}"
        ;;
    *)
        echo "unexpected things invocation: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$STUB_DIR/things"
    PATH="$STUB_DIR:$BATS_TEST_DIRNAME/../bin:$PATH"

    TODAY=$(date +%F)
    NOTE="$DAILY_DIR/$TODAY.org"
}

@test "imports a task with notes, completes it in Things" {
    cat >"$FIXTURES/inbox-tag.json" <<'EOF'
[{"uuid": "U1", "title": "Ping Ben about the report job", "notes": "context line", "status": "open"}]
EOF
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 1 task(s), skipped 0 duplicate(s)"* ]]

    grep -qxF '** TODO Ping Ben about the report job' "$NOTE"
    grep -qxF ':THINGS_ID: U1' "$NOTE"
    grep -qxF 'context line' "$NOTE"
    [ "$(cat "$THINGS_LOG")" = "complete U1" ]
}

@test "maps deadline and startDate to DEADLINE/SCHEDULED" {
    cat >"$FIXTURES/today-area.json" <<'EOF'
[{"uuid": "U2", "title": "Dated task", "deadline": "2026-07-22", "startDate": "2026-07-14"}]
EOF
    run things-to-daily
    [ "$status" -eq 0 ]
    grep -qxF 'DEADLINE: <2026-07-22> SCHEDULED: <2026-07-14>' "$NOTE"
}

@test "same uuid across views and filters is imported and completed once" {
    echo '[{"uuid": "U3", "title": "Dup"}]' >"$FIXTURES/inbox-tag.json"
    echo '[{"uuid": "U3", "title": "Dup"}]' >"$FIXTURES/anytime-area.json"
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 1 task(s)"* ]]
    [ "$(grep -cF '** TODO Dup' "$NOTE")" -eq 1 ]
    [ "$(wc -l <"$THINGS_LOG")" -eq 1 ]
}

@test "re-run skips the duplicate but still completes in Things" {
    echo '[{"uuid": "U4", "title": "Sticky"}]' >"$FIXTURES/inbox-tag.json"
    things-to-daily
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 0 task(s), skipped 1 duplicate(s)"* ]]
    [ "$(grep -cF '** TODO Sticky' "$NOTE")" -eq 1 ]
    [ "$(grep -c 'complete U4' "$THINGS_LOG")" -eq 2 ]
}

@test "complete failure warns but exits zero and keeps the entry" {
    echo '[{"uuid": "U5", "title": "Fragile"}]' >"$FIXTURES/inbox-tag.json"
    export THINGS_COMPLETE_EXIT=1
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning: failed to complete task in Things: U5"* ]]
    grep -qxF '** TODO Fragile' "$NOTE"
}

@test "task in both the area and tag lists is imported once" {
    echo '[{"uuid": "U6", "title": "Both filters"}]' >"$FIXTURES/today-area.json"
    echo '[{"uuid": "U6", "title": "Both filters"}]' >"$FIXTURES/today-tag.json"
    run things-to-daily
    [ "$status" -eq 0 ]
    [[ "$output" == *"imported 1 task(s)"* ]]
    [ "$(grep -cF '** TODO Both filters' "$NOTE")" -eq 1 ]
    [ "$(wc -l <"$THINGS_LOG")" -eq 1 ]
}
