#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)

# --- Colors ---
GREEN='\033[38;2;151;201;195m'
YELLOW='\033[38;2;229;192;123m'
RED='\033[38;2;224;108;117m'
GRAY='\033[38;2;74;88;92m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

color_for_pct() {
  local pct=$1
  if [ "$pct" -lt 50 ]; then echo "$GREEN"
  elif [ "$pct" -lt 80 ]; then echo "$YELLOW"
  else echo "$RED"
  fi
}

# --- Parse input JSON ---
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "unknown"')
CONTEXT_PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
CWD=$(echo "$INPUT" | jq -r '.cwd // .workspace.current_dir // ""')

# --- Git info ---
BRANCH=""
ADDITIONS=0
DELETIONS=0
if [ -n "$CWD" ] && [ -d "$CWD" ]; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || true)
  DIFFSTAT=$(git -C "$CWD" diff --numstat HEAD 2>/dev/null || true)
  if [ -n "$DIFFSTAT" ]; then
    ADDITIONS=$(echo "$DIFFSTAT" | awk '{s+=$1} END {print s+0}')
    DELETIONS=$(echo "$DIFFSTAT" | awk '{s+=$2} END {print s+0}')
  fi
  DIFFSTAT_STAGED=$(git -C "$CWD" diff --cached --numstat 2>/dev/null || true)
  if [ -n "$DIFFSTAT_STAGED" ]; then
    ADDITIONS=$(( ADDITIONS + $(echo "$DIFFSTAT_STAGED" | awk '{s+=$1} END {print s+0}') ))
    DELETIONS=$(( DELETIONS + $(echo "$DIFFSTAT_STAGED" | awk '{s+=$2} END {print s+0}') ))
  fi
fi

# --- Rate limit usage (from stdin JSON) ---
FIVE_HOUR_PCT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
FIVE_HOUR_RESET=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty')
SEVEN_DAY_PCT=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // 0' | cut -d. -f1)
SEVEN_DAY_RESET=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.resets_at // empty')

format_reset() {
  local ts=$1
  if [ -z "$ts" ] || [ "$ts" = "null" ] || [ "$ts" = "0" ]; then return; fi
  local today reset_date
  today=$(TZ=Asia/Tokyo date +%Y-%m-%d)
  reset_date=$(TZ=Asia/Tokyo date -d "@$ts" +%Y-%m-%d 2>/dev/null || return)
  if [ "$today" = "$reset_date" ]; then
    TZ=Asia/Tokyo date -d "@$ts" "+%-l%P" 2>/dev/null
  else
    TZ=Asia/Tokyo date -d "@$ts" "+%-m/%-d %-l%P" 2>/dev/null
  fi
}

FIVE_RESET=$(format_reset "$FIVE_HOUR_RESET")
SEVEN_RESET=$(format_reset "$SEVEN_DAY_RESET")

# --- Build single-line output ---
CTX_COLOR=$(color_for_pct "${CONTEXT_PCT:-0}")
FIVE_COLOR=$(color_for_pct "$FIVE_HOUR_PCT")
SEVEN_COLOR=$(color_for_pct "$SEVEN_DAY_PCT")
SEP="${GRAY} · ${RESET}"

OUT="${BOLD}${MODEL}${RESET}"
OUT+="${SEP}${CTX_COLOR}${CONTEXT_PCT:-0}% used${RESET}"
OUT+="${SEP}${GREEN}+${ADDITIONS}${RESET}${GRAY}/${RESET}${RED}-${DELETIONS}${RESET}"
if [ -n "$BRANCH" ]; then
  OUT+="${SEP}${DIM}${BRANCH}${RESET}"
fi
OUT+="${SEP}5h ${FIVE_COLOR}${FIVE_HOUR_PCT}%${RESET}"
if [ -n "$FIVE_RESET" ]; then OUT+="${DIM} @${FIVE_RESET}${RESET}"; fi
OUT+="${SEP}7d ${SEVEN_COLOR}${SEVEN_DAY_PCT}%${RESET}"
if [ -n "$SEVEN_RESET" ]; then OUT+="${DIM} @${SEVEN_RESET}${RESET}"; fi

echo -e "$OUT"
