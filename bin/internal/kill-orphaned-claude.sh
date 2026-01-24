#!/usr/bin/env zsh
# Kill claude processes that have been orphaned (re-parented to PID 1/launchd).
# This happens when a parent Claude Code session dies without cleaning up sub-agents.

ps -eo pid,ppid,comm | grep '[c]laude' | awk '$2 == 1 { print $1 }' | while read pid; do
  kill "$pid" 2>/dev/null
done
