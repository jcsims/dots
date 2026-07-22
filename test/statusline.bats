#!/usr/bin/env bats

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../config/claude/statusline.sh"
    # Pin "now" so time-until-reset is deterministic.
    export STATUSLINE_NOW_EPOCH=1000000000
    PAYLOAD="$BATS_TEST_TMPDIR/payload.json"
    # resets_at are relative to the pinned NOW above:
    #   session: +7130s -> 1h58m ; weekly: +273600s -> 3d4h
    cat >"$PAYLOAD" <<'JSON'
{
  "cwd": "/Users/x/proj",
  "model": { "display_name": "Opus" },
  "output_style": { "name": "default" },
  "context_window": {
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 8000,
      "cache_creation_input_tokens": 1000,
      "cache_read_input_tokens": 1000
    }
  },
  "rate_limits": {
    "five_hour": { "used_percentage": 23, "resets_at": 1000007130 },
    "seven_day": { "used_percentage": 41, "resets_at": 1000273600 }
  }
}
JSON
}

@test "shows time until reset for both windows" {
    run bash -c "bash '$SCRIPT' <'$PAYLOAD'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"23% sess (1h58m)"* ]]
    [[ "$output" == *"41% wk (3d4h)"* ]]
}

@test "weekly under an hour formats as minutes only" {
    run bash -c "jq '.rate_limits.seven_day.resets_at = 1000001500' '$PAYLOAD' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"41% wk (25m)"* ]]
}

@test "no rate_limits -> no limits segment" {
    run bash -c "jq 'del(.rate_limits)' '$PAYLOAD' | bash '$SCRIPT'"
    [ "$status" -eq 0 ]
    [[ "$output" != *"sess"* ]]
    [[ "$output" != *"wk"* ]]
}
