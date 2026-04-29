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

# Replace home directory with ~
cwd="${cwd/$HOME/~}"

# Define colors
cyan='\033[36m'
reset='\033[0m'

# Calculate context percentage
ctx_percent=$((context_current * 100 / context_max))

# Rate-limit segment — absent for non-subscribers and before the first API response
limits_segment=""
if [[ -n "$five_hour_pct" || -n "$seven_day_pct" ]]; then
    sess="${five_hour_pct:+$(printf "%.0f" "$five_hour_pct")}"
    week="${seven_day_pct:+$(printf "%.0f" "$seven_day_pct")}"
    limits_segment=$(printf " | ${cyan}%s%% sess / %s%% wk${reset}" "${sess:-—}" "${week:-—}")
fi

# Build and output the status line
printf "${cyan}%s${reset} | ${cyan}%s${reset} | ${cyan}%s${reset} | ${cyan}%s%% ctx${reset}%s\n" "$cwd" "$model" "$output_style" "$ctx_percent" "$limits_segment"
