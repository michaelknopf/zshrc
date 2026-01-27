#!/usr/bin/env zsh
# Kill orphaned Claude Code processes (re-parented to PID 1/launchd).
#
# Performance optimization: The previous implementation used `grep '[c]laude'` which
# was too broad and matched MCP server subprocesses whose paths contain "claude"
# (e.g., ~/.claude/plugins/cache/savi-tools/.../mcp-remote). During graceful
# shutdown, Claude Code waits for child processes to terminate. If this LaunchAgent
# killed them prematurely (runs every 60s), Claude would hang waiting for processes
# that were already dead, adding significant exit overhead.
#
# Fix: Use awk pattern `/\/claude$/` to match ONLY processes whose comm field ends
# with "/claude", ensuring we target the actual claude binary and not subprocesses.
#
# Impact: Eliminates 3-5s shutdown hangs caused by premature child process kills.
#
# Related: This fix works in conjunction with CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
# (see zshrc.d/claude.sh) to reduce total startup+shutdown time from 10-12s to 3-4s.

ps -eo pid,ppid,comm | awk '$2 == 1 && $3 ~ /\/claude$/ { print $1 }' | while read pid; do
  kill "$pid" 2>/dev/null
done
