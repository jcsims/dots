#!/usr/bin/env bats

setup() {
    export OBSIDIAN_VAULT_DIR="$BATS_TEST_TMPDIR/vault"
    export OBSIDIAN_VAULT="testvault"
    export THINGS_AREA="Work"
    export THINGS_TAG="@work"
    export THINGS_STORE="$BATS_TEST_TMPDIR/things-store.json"
    STUB_DIR="$BATS_TEST_TMPDIR/stub"
    mkdir -p "$OBSIDIAN_VAULT_DIR" "$STUB_DIR"
    echo '[]' >"$THINGS_STORE"

    # Stub `things` backed by a JSON store file ($THINGS_STORE):
    #   add <title> [--list L] [--tags T] [--notes N]
    #       appends {uuid,title,list,tags,notes,status:"open"} with a
    #       deterministic incrementing uuid (U1, U2, ...). If
    #       THINGS_ADD_NOOP is set, does nothing (simulates a create whose
    #       new task doesn't show up in the list yet).
    #   list anytime --area <A> -j
    #       prints the store filtered to tasks whose list == A.
    #   show <uuid> -j
    #       prints {"uuid","status"} for a stored task, or nothing if the
    #       uuid isn't in the store.
    #   anything else (including cancel) is unexpected, like
    #   things-to-daily's stub.
    cat >"$STUB_DIR/things" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
STORE="$THINGS_STORE"
case "$1" in
    add)
        if [ -n "${THINGS_ADD_NOOP:-}" ]; then
            exit 0
        fi
        shift
        title="$1"
        shift
        list=""
        tags=""
        notes=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --list) list="$2"; shift 2 ;;
                --tags) tags="$2"; shift 2 ;;
                --notes) notes="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        count=$(jq 'length' "$STORE")
        uuid="U$((count + 1))"
        tmp=$(mktemp)
        jq --arg uuid "$uuid" --arg title "$title" --arg list "$list" \
           --arg tags "$tags" --arg notes "$notes" \
           '. + [{"uuid":$uuid,"title":$title,"list":$list,"tags":$tags,"notes":$notes,"status":"open"}]' \
           "$STORE" >"$tmp"
        mv "$tmp" "$STORE"
        ;;
    list)
        view="$2"
        shift 2
        area=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --area) area="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        if [ "$view" != "anytime" ]; then
            echo null
            exit 0
        fi
        jq --arg area "$area" '[.[] | select(.list == $area)]' "$STORE"
        ;;
    show)
        uuid="$2"
        jq --arg uuid "$uuid" '[.[] | select(.uuid == $uuid) | {uuid, status}] | .[0] // empty' "$STORE"
        ;;
    *)
        echo "unexpected things invocation: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$STUB_DIR/things"
    PATH="$STUB_DIR:$BATS_TEST_DIRNAME/../bin:$PATH"
}

mark_status() {
    local uuid="$1" status="$2" tmp
    tmp=$(mktemp)
    jq --arg uuid "$uuid" --arg status "$status" \
       'map(if .uuid == $uuid then .status = $status else . end)' \
       "$THINGS_STORE" >"$tmp"
    mv "$tmp" "$THINGS_STORE"
}

store_titles() {
    jq -r '.[].title' "$THINGS_STORE"
}

store_count() {
    jq 'length' "$THINGS_STORE"
}

# --- push ---

@test "push: unchecked checkbox creates a task and rewrites the line with an id link" {
    mkdir -p "$OBSIDIAN_VAULT_DIR/notes"
    cat >"$OBSIDIAN_VAULT_DIR/notes/todo.md" <<'EOF'
# Notes

- [ ] Call the vet
EOF
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 1 todo(s), skipped 0 already-linked, 0 warning(s)"* ]]

    grep -qxF -- '- [ ] Call the vet [⤴](things:///show?id=U1)' "$OBSIDIAN_VAULT_DIR/notes/todo.md"

    [ "$(store_count)" -eq 1 ]
    [ "$(store_titles)" = "Call the vet" ]
    [ "$(jq -r '.[0].list' "$THINGS_STORE")" = "Work" ]
    [ "$(jq -r '.[0].tags' "$THINGS_STORE")" = "@work" ]
}

@test "push: plain checkbox with no tag is still pushed and linked" {
    cat >"$OBSIDIAN_VAULT_DIR/plain.md" <<'EOF'
- [ ] Buy milk
EOF
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 1 todo(s), skipped 0 already-linked, 0 warning(s)"* ]]
    grep -qxF -- '- [ ] Buy milk [⤴](things:///show?id=U1)' "$OBSIDIAN_VAULT_DIR/plain.md"
    [ "$(store_count)" -eq 1 ]
    [ "$(store_titles)" = "Buy milk" ]
}

@test "push: a hashtag in the checkbox text is preserved verbatim in the title" {
    cat >"$OBSIDIAN_VAULT_DIR/plain.md" <<'EOF'
- [ ] review #reng thing
EOF
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 1 todo(s), skipped 0 already-linked, 0 warning(s)"* ]]
    [ "$(store_titles)" = "review #reng thing" ]
    grep -qxF -- '- [ ] review #reng thing [⤴](things:///show?id=U1)' "$OBSIDIAN_VAULT_DIR/plain.md"
}

@test "push: a checked box is never a candidate and is left untouched" {
    cat >"$OBSIDIAN_VAULT_DIR/plain.md" <<'EOF'
- [x] Already done
EOF
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 0 todo(s), skipped 0 already-linked, 0 warning(s)"* ]]
    grep -qxF -- '- [x] Already done' "$OBSIDIAN_VAULT_DIR/plain.md"
    [ "$(store_count)" -eq 0 ]
}

@test "push: continuation lines are copied into notes, dedented, and a nested task stops consumption" {
    mkdir -p "$OBSIDIAN_VAULT_DIR/notes"
    cat >"$OBSIDIAN_VAULT_DIR/notes/todo.md" <<'EOF'
- [ ] Follow up with Jamie
  She mentioned budget numbers by Friday.
  Ping Cody too.
  - [ ] Nested subtask not fetched
- [ ] Another top-level task
EOF
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]

    # The parent task's notes stop at the nested task line.
    notes=$(jq -r '.[0].notes' "$THINGS_STORE")
    [[ "$notes" == *"She mentioned budget numbers by Friday."* ]]
    [[ "$notes" == *"Ping Cody too."* ]]
    [[ "$notes" != *"Nested subtask"* ]]

    # Every unchecked checkbox is its own push candidate now, so the
    # nested task and the following top-level task are pushed too, each
    # getting its own Things task and id link (indentation preserved).
    [ "$(store_count)" -eq 3 ]
    grep -qxF '  - [ ] Nested subtask not fetched [⤴](things:///show?id=U2)' "$OBSIDIAN_VAULT_DIR/notes/todo.md"
    grep -qxF -- '- [ ] Another top-level task [⤴](things:///show?id=U3)' "$OBSIDIAN_VAULT_DIR/notes/todo.md"
}

@test "push: notes include an obsidian:// backlink with url-encoded vault-relative path" {
    mkdir -p "$OBSIDIAN_VAULT_DIR/Project Notes"
    cat >"$OBSIDIAN_VAULT_DIR/Project Notes/todo.md" <<'EOF'
- [ ] Draft the proposal
EOF
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]

    notes=$(jq -r '.[0].notes' "$THINGS_STORE")
    first_line=$(head -n1 <<<"$notes")
    [ "$first_line" = "obsidian://open?vault=testvault&file=Project%20Notes%2Ftodo" ]
}

@test "push: files under archive/ and templates/ are skipped" {
    mkdir -p "$OBSIDIAN_VAULT_DIR/archive" "$OBSIDIAN_VAULT_DIR/templates"
    echo '- [ ] Old task' >"$OBSIDIAN_VAULT_DIR/archive/old.md"
    echo '- [ ] Template task' >"$OBSIDIAN_VAULT_DIR/templates/tpl.md"
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 0 todo(s), skipped 0 already-linked, 0 warning(s)"* ]]
    grep -qxF -- '- [ ] Old task' "$OBSIDIAN_VAULT_DIR/archive/old.md"
    grep -qxF -- '- [ ] Template task' "$OBSIDIAN_VAULT_DIR/templates/tpl.md"
    [ "$(store_count)" -eq 0 ]
}

@test "push: re-run is a no-op, counting the already-linked line as skipped" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Call the vet
EOF
    obsidian-todo-to-things push
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 0 todo(s), skipped 1 already-linked, 0 warning(s)"* ]]
    [ "$(store_count)" -eq 1 ]
}

@test "push: zero-uuid-diff create warns and uses a query-link fallback" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Mystery task
EOF
    export THINGS_ADD_NOOP=1
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning:"* ]]
    [[ "$output" == *"pushed 1 todo(s), skipped 0 already-linked, 1 warning(s)"* ]]
    grep -qF -- 'things:///show?query=Mystery%20task' "$OBSIDIAN_VAULT_DIR/todo.md"
    [ "$(store_count)" -eq 0 ]

    # The dedupe marker is an id= link (per the spec); a query-link
    # fallback has no uuid to dedupe on, so the line (lacking id=) is
    # still a push candidate on re-run and gets processed again.
    run obsidian-todo-to-things push
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 1 todo(s), skipped 0 already-linked, 1 warning(s)"* ]]
}

# --- sync ---

@test "sync: completed linked task flips the checkbox and keeps the link" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Call the vet
EOF
    obsidian-todo-to-things push
    mark_status U1 completed

    run obsidian-todo-to-things sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"completed 1 todo(s) from Things, 0 warning(s)"* ]]
    grep -qxF -- '- [x] Call the vet [⤴](things:///show?id=U1)' "$OBSIDIAN_VAULT_DIR/todo.md"
}

@test "sync: open linked task is left unchanged" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Call the vet
EOF
    obsidian-todo-to-things push
    run obsidian-todo-to-things sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"completed 0 todo(s) from Things, 0 warning(s)"* ]]
    grep -qxF -- '- [ ] Call the vet [⤴](things:///show?id=U1)' "$OBSIDIAN_VAULT_DIR/todo.md"
}

@test "sync: canceled linked task is left unchanged" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Call the vet
EOF
    obsidian-todo-to-things push
    mark_status U1 canceled

    run obsidian-todo-to-things sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"completed 0 todo(s) from Things, 0 warning(s)"* ]]
    grep -qxF -- '- [ ] Call the vet [⤴](things:///show?id=U1)' "$OBSIDIAN_VAULT_DIR/todo.md"
}

@test "sync: unknown uuid warns and leaves the line unchanged" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Ghost task [⤴](things:///show?id=U404)
EOF
    run obsidian-todo-to-things sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"warning:"* ]]
    [[ "$output" == *"U404"* ]]
    [[ "$output" == *"completed 0 todo(s) from Things, 1 warning(s)"* ]]
    grep -qxF -- '- [ ] Ghost task [⤴](things:///show?id=U404)' "$OBSIDIAN_VAULT_DIR/todo.md"
}

# --- no-arg ---

@test "no-arg runs push then sync, printing both summaries" {
    cat >"$OBSIDIAN_VAULT_DIR/todo.md" <<'EOF'
- [ ] Call the vet
- [ ] Already done [⤴](things:///show?id=U404)
EOF
    echo '[{"uuid":"U404","title":"Already done","list":"Work","tags":"@work","notes":"","status":"completed"}]' >"$THINGS_STORE"

    run obsidian-todo-to-things
    [ "$status" -eq 0 ]
    [[ "$output" == *"pushed 1 todo(s), skipped 1 already-linked, 0 warning(s)"* ]]
    [[ "$output" == *"completed 1 todo(s) from Things, 0 warning(s)"* ]]
    grep -qxF -- '- [x] Already done [⤴](things:///show?id=U404)' "$OBSIDIAN_VAULT_DIR/todo.md"
}
