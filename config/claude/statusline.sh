#!/usr/bin/env bash

# Claude Code statusline script
# Reads JSON from stdin and outputs a formatted status line

# Read JSON input from stdin
json_input=$(cat)

# Extract values using jq
cwd=$(echo "$json_input" | jq -r '.cwd // ""')
model=$(echo "$json_input" | jq -r '.model.display_name // ""')
output_style=$(echo "$json_input" | jq -r '.output_style.name // ""')
usage=$(echo "$json_input" | jq -r '.context_window.current_usage')
context_current=$(echo "$usage" | jq -r '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens // 0')
context_max=$(echo "$json_input" | jq -r '.context_window.context_window_size // 0')
five_hour_pct=$(echo "$json_input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
seven_day_pct=$(echo "$json_input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
five_hour_reset=$(echo "$json_input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_day_reset=$(echo "$json_input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# Current epoch; overridable so the time-until-reset formatting is testable
now="${STATUSLINE_NOW_EPOCH:-$(date +%s)}"

# Replace home directory with ~
cwd="${cwd/$HOME/~}"

# Define colors
cyan='\033[36m'
reset='\033[0m'

# Format seconds-until-reset as a compact "3d4h" / "1h58m" / "25m" string.
# Prints nothing when the target epoch is missing.
fmt_reset() {
    local target="$1" delta days hours mins
    [[ -z "$target" || "$target" == "null" ]] && return
    delta=$((target - now))
    ((delta < 0)) && delta=0
    days=$((delta / 86400))
    hours=$(((delta % 86400) / 3600))
    mins=$(((delta % 3600) / 60))
    if ((days > 0)); then
        printf '%dd%dh' "$days" "$hours"
    elif ((hours > 0)); then
        printf '%dh%dm' "$hours" "$mins"
    else
        printf '%dm' "$mins"
    fi
}

# Calculate context percentage
ctx_percent=$((context_current * 100 / context_max))

# Rate-limit segment — absent for non-subscribers and before the first API response.
# Each window shows used percent plus time until it resets, e.g. "23% sess (1h58m)".
limits_segment=""
if [[ -n "$five_hour_pct" || -n "$seven_day_pct" ]]; then
    sess="${five_hour_pct:+$(printf "%.0f" "$five_hour_pct")}"
    week="${seven_day_pct:+$(printf "%.0f" "$seven_day_pct")}"
    sess_reset=$(fmt_reset "$five_hour_reset")
    week_reset=$(fmt_reset "$seven_day_reset")
    sess_seg=$(printf '%s%% sess' "${sess:-—}")
    week_seg=$(printf '%s%% wk' "${week:-—}")
    [[ -n "$sess_reset" ]] && sess_seg="$sess_seg ($sess_reset)"
    [[ -n "$week_reset" ]] && week_seg="$week_seg ($week_reset)"
    limits_segment=$(printf ' | %b%s / %s%b' "$cyan" "$sess_seg" "$week_seg" "$reset")
fi

# Build and output the status line
printf "${cyan}%s${reset} | ${cyan}%s${reset} | ${cyan}%s${reset} | ${cyan}%s%% ctx${reset}%s\n" "$cwd" "$model" "$output_style" "$ctx_percent" "$limits_segment"
