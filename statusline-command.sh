#!/usr/bin/env bash
input=$(cat)

CYAN='\033[36m' GREEN='\033[32m' YELLOW='\033[33m' RED='\033[31m'
MAG='\033[35m' DIM='\033[2m' BOLD='\033[1m' R='\033[0m'
SEP="${DIM} | ${R}"

parts=()

# Model
model=$(echo "$input" | jq -r '.model.display_name // .model.id // empty')
[ -n "$model" ] && parts+=("${BOLD}${CYAN}${model}${R}")

# Account
if command -v claude &>/dev/null; then
  auth=$(claude auth status --json 2>/dev/null)
  if [ -n "$auth" ]; then
    email=$(echo "$auth" | jq -r '.email // empty')
    org=$(echo "$auth" | jq -r '.orgName // empty')
    if [ -n "$email" ]; then
      user="${email%%@*}"
      acct="${user}"
      domain="${email##*@}"
      if [ -n "$org" ]; then
        lc_org=$(echo "$org" | tr '[:upper:]' '[:lower:]')
        lc_user=$(echo "$user" | tr '[:upper:]' '[:lower:]')
        lc_email=$(echo "$email" | tr '[:upper:]' '[:lower:]')
        if [[ "$lc_org" == *"$lc_user"* || "$lc_org" == *"$lc_email"* ]]; then
          acct="${user} (${domain})"
        else
          acct="${user} (${org})"
        fi
      else
        acct="${user} (${domain})"
      fi
      parts+=("${DIM}${acct}${R}")
    fi
  fi
fi

# Context bar (filled = used, so bar fills up as context is consumed)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
if [ -n "$used_pct" ] && [ -n "$ctx_size" ]; then
  pct=$(printf '%.0f' "$used_pct")
  if [ "$pct" -ge 80 ]; then c=$RED
  elif [ "$pct" -ge 50 ]; then c=$YELLOW
  else c=$GREEN; fi
  filled=$((pct / 10)); empty=$((10 - filled))
  bar=""; for ((i=0;i<filled;i++)); do bar+="━"; done
  pad=""; for ((i=0;i<empty;i++)); do pad+="─"; done
  used_k=$(awk "BEGIN{printf \"%.0fk\", $ctx_size*$used_pct/100000}")
  ctx_k=$(awk "BEGIN{printf \"%dk\", $ctx_size/1000}")
  parts+=("${c}${bar}${DIM}${pad}${R} ${c}${used_k}${R}${DIM}/${ctx_k}${R} ${c}${pct}%${R}")
fi

# Tokens
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
if [ -n "$total_in" ] && [ -n "$total_out" ]; then
  in_k=$(awk "BEGIN{printf \"%.1fk\", $total_in/1000}")
  out_k=$(awk "BEGIN{printf \"%.1fk\", $total_out/1000}")
  parts+=("${MAG}${in_k}${R}${DIM}in${R} ${MAG}${out_k}${R}${DIM}out${R}")
fi

# Fuel gauge helper: fuel_gauge <used_pct> <reset_epoch> <label>
# Gauge shows usage (█=used, ░=remaining) - fills up as quota is consumed
epoch_fmt() {
  local epoch=$1 fmt=$2
  if date -d @0 '+%s' &>/dev/null 2>&1; then
    date -d "@$epoch" "+$fmt"
  elif date -r 0 '+%s' &>/dev/null 2>&1; then
    date -r "$epoch" "+$fmt"
  elif command -v powershell.exe &>/dev/null; then
    # Windows: convert POSIX strftime format to .NET format for PowerShell
    local net_fmt="$fmt"
    net_fmt="${net_fmt//%Y/yyyy}"; net_fmt="${net_fmt//%m/MM}"; net_fmt="${net_fmt//%d/dd}"
    net_fmt="${net_fmt//%H/HH}";   net_fmt="${net_fmt//%M/mm}"; net_fmt="${net_fmt//%S/ss}"
    net_fmt="${net_fmt//%a/ddd}"
    powershell.exe -NoProfile -Command \
      "[DateTimeOffset]::FromUnixTimeSeconds($epoch).LocalDateTime.ToString('$net_fmt')"
  else
    echo "?"
  fi
}

fuel_gauge() {
  local used_pct_raw=$1 reset_at=$2 label=$3
  local used=$(printf '%.0f' "$used_pct_raw")
  [ "$used" -lt 0 ] && used=0
  [ "$used" -gt 100 ] && used=100
  # Color based on usage (more used = worse)
  local gc
  if [ "$used" -ge 80 ]; then gc=$RED
  elif [ "$used" -ge 50 ]; then gc=$YELLOW
  else gc=$GREEN; fi

  # Build 10-char gauge
  local filled=$((used / 10))
  local empty_count=$((10 - filled))
  local bar="" pad=""
  for ((i=0;i<filled;i++)); do bar+="█"; done
  for ((i=0;i<empty_count;i++)); do pad+="░"; done

  # Reset time: relative + absolute
  local now=$(date +%s)
  local secs_left=$(( reset_at - now ))
  local rel abs_time

  if [ "$secs_left" -le 0 ]; then
    rel="now"
    abs_time=""
  else
    local mins_left=$(( secs_left / 60 ))
    if [ "$mins_left" -eq 0 ]; then
      rel="<1m"
      abs_time=$(epoch_fmt "$reset_at" '%H:%M')
    elif [ "$mins_left" -lt 60 ]; then
      rel="~${mins_left}m"
      abs_time=$(epoch_fmt "$reset_at" '%H:%M')
    elif [ "$mins_left" -lt 1380 ]; then
      local h=$(awk "BEGIN{printf \"%.1f\", $mins_left/60}")
      rel="~${h}h"
      abs_time=$(epoch_fmt "$reset_at" '%H:%M')
    else
      local d=$(( (mins_left + 1439) / 1440 ))
      rel="~${d}d"
      abs_time=$(epoch_fmt "$reset_at" '%a %H:%M')
    fi
  fi

  local time_str="${rel}"
  [ -n "$abs_time" ] && time_str="${rel} (${abs_time})"

  parts+=("${gc}${label} ${bar}${DIM}${pad}${R} ${gc}${used}% used${R} ${DIM}${time_str}${R}")
}

# Rate limits
five_h_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_d_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_d_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

[ -n "$five_h_pct" ] && fuel_gauge "$five_h_pct" "$five_h_reset" "5h"
[ -n "$seven_d_pct" ] && fuel_gauge "$seven_d_pct" "$seven_d_reset" "7d"

# Join with separator
out=""
for i in "${!parts[@]}"; do
  [ "$i" -gt 0 ] && out+="$SEP"
  out+="${parts[$i]}"
done
printf '%b' "$out"
