#!/usr/bin/env zsh
# Kill the main claude binary that has been orphaned (re-parented to PID 1/launchd).
# Only targets the actual claude binary, not MCP servers or other subprocesses
# running from paths under ~/.claude/.

ps -eo pid,ppid,comm | awk '$2 == 1 && $3 ~ /\/claude$/ { print $1 }' | while read pid; do
  kill "$pid" 2>/dev/null
done
