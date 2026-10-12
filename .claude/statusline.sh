#!/usr/bin/env bash
# Claude Code status line
# Receives JSON on stdin; outputs a single formatted line.

input=$(cat)

# Parse all fields in one jq call, tab-separated
IFS=$'\t' read -r model_raw cwd used_pct cost_raw five_hour_raw <<< "$(
  echo "$input" | jq -r '
    [
      (.model.display_name // ""),
      (.workspace.current_dir // ""),
      (.context_window.used_percentage // ""),
      (.cost.total_cost_usd // ""),
      (.rate_limits.five_hour.used_percentage // "")
    ] | @tsv
  '
)"

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

# ── Cost ──────────────────────────────────────────────────────────────────────
cost_str=""
if [ -n "$cost_raw" ] && [ "$cost_raw" != "null" ]; then
  cost_str=$(printf '\033[33m$%.2f\033[0m' "$cost_raw")
fi

# ── Context bar ───────────────────────────────────────────────────────────────
ctx_str=""
if [ -n "$used_pct" ] && [ "$used_pct" != "null" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  filled=$(( pct_int * 10 / 100 ))
  [ $filled -gt 10 ] && filled=10
  empty=$(( 10 - filled ))

  # Color thresholds: green ≤50, yellow 51-80, red >80
  if [ "$pct_int" -le 50 ]; then
    bar_color='\033[32m'   # green
  elif [ "$pct_int" -le 80 ]; then
    bar_color='\033[33m'   # yellow
  else
    bar_color='\033[31m'   # red
  fi

  bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++));  do bar="${bar}░"; done

  ctx_str=$(printf "${bar_color}[%s]\033[0m %d%%" "$bar" "$pct_int")
fi

# ── 5-hour rate limit ─────────────────────────────────────────────────────────
rate_str=""
if [ -n "$five_hour_raw" ] && [ "$five_hour_raw" != "null" ]; then
  rate_pct=$(printf '%.0f' "$five_hour_raw")
  rate_str=$(printf '5h:%d%%' "$rate_pct")
fi

# ── Monthly ccusage cost (cached, background-refreshed) ───────────────────────
MONTHLY_CACHE="/tmp/claude-statusline-monthly.cache"
CACHE_TTL=600   # 10 minutes in seconds
now=$(date +%s)

monthly_str=""
if [ -f "$MONTHLY_CACHE" ] && [ -s "$MONTHLY_CACHE" ]; then
  cache_age=$(( now - $(stat -f %m "$MONTHLY_CACHE" 2>/dev/null || echo "$now") ))

  # Stale — spawn background refresh (guard against pile-up via .tmp mtime)
  if [ "$cache_age" -gt "$CACHE_TTL" ]; then
    tmp_age=999999
    if [ -f "${MONTHLY_CACHE}.tmp" ]; then
      tmp_age=$(( now - $(stat -f %m "${MONTHLY_CACHE}.tmp" 2>/dev/null || echo 0) ))
    fi
    if [ "$tmp_age" -gt 60 ]; then
      ( npx -y ccusage@latest monthly --json > "${MONTHLY_CACHE}.tmp" 2>/dev/null \
          && mv "${MONTHLY_CACHE}.tmp" "$MONTHLY_CACHE" ) &
      disown 2>/dev/null || true
    fi
  fi

  # Render from whatever is in the cache right now (may be up to TTL old — fine)
  current_month=$(date +%Y-%m)
  mo_cost=$(jq -r --arg month "$current_month" \
    '[.monthly[] | select(.period == $month) | select(.metadata.agents | index("claude"))] | map(.totalCost) | add // 0' \
    "$MONTHLY_CACHE" 2>/dev/null)

  if [ -n "$mo_cost" ] && [ "$mo_cost" != "null" ]; then
    monthly_str=$(printf '\033[33m~mo:$%.2f\033[0m' "$mo_cost")
  fi
else
  # No cache yet — show placeholder and kick off first fetch
  monthly_str="~mo:…"
  tmp_age=999999
  if [ -f "${MONTHLY_CACHE}.tmp" ]; then
    tmp_age=$(( now - $(stat -f %m "${MONTHLY_CACHE}.tmp" 2>/dev/null || echo 0) ))
  fi
  if [ "$tmp_age" -gt 60 ]; then
    ( npx -y ccusage@latest monthly --json > "${MONTHLY_CACHE}.tmp" 2>/dev/null \
        && mv "${MONTHLY_CACHE}.tmp" "$MONTHLY_CACHE" ) &
    disown 2>/dev/null || true
  fi
fi

# ── Assemble output ───────────────────────────────────────────────────────────
SEP=$(printf '\033[2;37m │ \033[0m')   # dim grey separator

out=""

# Model
[ -n "$model" ] && out="${model}"

# Dir
if [ -n "$dir" ]; then
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}$(printf '\033[36m%s\033[0m' "$dir")"
fi

# Branch
if [ -n "$branch" ]; then
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}$(printf '\033[35m%s\033[0m' "$branch")"
fi

# Cost
if [ -n "$cost_str" ]; then
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}${cost_str}"
fi

# Monthly cost
if [ -n "$monthly_str" ]; then
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}${monthly_str}"
fi

# Context bar
if [ -n "$ctx_str" ]; then
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}${ctx_str}"
fi

# Rate limit
if [ -n "$rate_str" ]; then
  [ -n "$out" ] && out="${out}${SEP}"
  out="${out}${rate_str}"
fi

printf '%b\n' "$out"
