#!/usr/bin/env zsh
# Opportunistic delayed-archive sweep, run hourly by com.mknopf.gmail-sweep.
#
# `gws` credentials expire roughly daily: its OAuth client requests restricted scopes that are
# not declared on its consent screen, so Google treats the grant as unverified. Rather than fix
# that (a weeks-long verification review), this runs every hour during waking hours and takes
# whichever hour happens to fall after a manual `gws_auth`. An auth failure is therefore a
# normal outcome, not an error — hence the unconditional exit 0 at the end.
#
# Deliberately not `set -e`: a non-zero sweep is the case this script exists to handle.
set -uo pipefail

SCRIPT=/Users/mknopf/code/github/savi/claude-code-plugins/plugins/mk/scripts/gmail-filters.py
STATE_DIR="$HOME/.local/state/gmail-sweep"
STATE_FILE="$STATE_DIR/last-success"
LOG=/tmp/gmail-sweep.log
MAX_LOG_BYTES=1048576

mkdir -p "$STATE_DIR"

# Rotate before writing so a long run of failures can't grow the log without bound.
if [[ -f "$LOG" ]]; then
  size=$(stat -f%z "$LOG" 2>/dev/null || echo 0)
  if (( size > MAX_LOG_BYTES )); then
    mv -f "$LOG" "$LOG.1"
  fi
fi

log() { print -r -- "$(date '+%Y-%m-%d %H:%M:%S') $*" >>"$LOG" }

today=$(date '+%Y-%m-%d')
if [[ -f "$STATE_FILE" && "$(<"$STATE_FILE")" == "$today" ]]; then
  log "already succeeded today — skipping"
  exit 0
fi

log "=== running sweep ==="
"$SCRIPT" sweep --apply >>"$LOG" 2>&1
rc=$?

if (( rc == 0 )); then
  print -r -- "$today" >"$STATE_FILE"
  log "SUCCESS — marked today done"
else
  log "SKIPPED (auth or API failure, exit $rc) — will retry next hour"
fi

exit 0
