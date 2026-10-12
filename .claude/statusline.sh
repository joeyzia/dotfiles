#!/usr/bin/env bash
# Claude Code status line
# Receives JSON on stdin; outputs a single formatted line.

input=$(cat)

# Parse all fields in one jq call, tab-separated
IFS=$'\t' read -r model_raw cwd used_pct five_hour_raw five_hour_reset seven_day_raw seven_day_reset <<< "$(
  echo "$input" | jq -r '
    [
      (.model.display_name // ""),
      (.workspace.current_dir // ""),
      (.context_window.used_percentage // ""),
      (.rate_limits.five_hour.used_percentage // ""),
      (.rate_limits.five_hour.resets_at // ""),
      (.rate_limits.seven_day.used_percentage // ""),
      (.rate_limits.seven_day.resets_at // "")
    ] | @tsv
  '
)"

pct_color() {
  if [ "$1" -le 50 ]; then
    printf '\033[32m'
  elif [ "$1" -le 80 ]; then
    printf '\033[33m'
  else
    printf '\033[31m'
  fi
}

time_until() {
  local secs=$(( $1 - $(date +%s) ))

  [ "$secs" -le 0 ] && return

  local d=$(( secs / 86400 )) h=$(( secs % 86400 / 3600 )) m=$(( secs % 3600 / 60 ))

  if [ "$d" -gt 0 ]; then
    printf '%dd%dh' "$d" "$h"
  elif [ "$h" -gt 0 ]; then
    printf '%dh%dm' "$h" "$m"
  else
    printf '%dm' "$m"
  fi
}

usage_window() {
  local label="$1" pct_raw="$2" reset="$3"

  [ -z "$pct_raw" ] || [ "$pct_raw" = "null" ] && return

  local pct
  pct=$(printf '%.0f' "$pct_raw")

  local str
  str=$(printf '%s%s:%d%%\033[0m' "$(pct_color "$pct")" "$label" "$pct")

  if [ -n "$reset" ] && [ "$reset" != "null" ]; then
    local left
    left=$(time_until "${reset%.*}")
    [ -n "$left" ] && str="${str}$(printf ' \033[2m↻%s\033[0m' "$left")"
  fi

  printf '%s' "$str"
}

# ── Model: strip "Claude " prefix ─────────────────────────────────────────────
model="${model_raw#Claude }"

# ── Working directory: basename only ──────────────────────────────────────────
dir="${cwd##*/}"
[ -z "$dir" ] && dir="/"

# ── Git branch (skip optional locks) ──────────────────────────────────────────
branch=""
if [ -n "$cwd" ]; then
  branch=$(git --no-optional-locks -C "$cwd" branch --show-current 2>/dev/null)
fi

# ── Context bar ───────────────────────────────────────────────────────────────
ctx_str=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  filled=$(( pct_int * 10 / 100 ))
  [ $filled -gt 10 ] && filled=10
  empty=$(( 10 - filled ))

  bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++));  do bar="${bar}░"; done

  ctx_str=$(printf "%s[%s]\033[0m %d%%" "$(pct_color "$pct_int")" "$bar" "$pct_int")
fi

# ── Subscription usage windows ────────────────────────────────────────────────
five_hour_str=$(usage_window 5h "$five_hour_raw" "$five_hour_reset")
seven_day_str=$(usage_window 7d "$seven_day_raw" "$seven_day_reset")

# ── Assemble output ───────────────────────────────────────────────────────────
SEP=$(printf '\033[2;37m │ \033[0m')   # dim grey separator

out=""

append() {
  [ -z "$1" ] && return
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}$1"
}

append "$model"
append "$(printf '\033[36m%s\033[0m' "$dir")"
[ -n "$branch" ] && append "$(printf '\033[35m%s\033[0m' "$branch")"
append "$ctx_str"
append "$five_hour_str"
append "$seven_day_str"

printf '%b\n' "$out"
