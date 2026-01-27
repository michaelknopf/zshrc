
# For analytics dashboard:
#   claude-code-templates --analytics

# Performance: Prevent Claude from updating terminal title on every prompt.
# Minor optimization, primarily for cleaner terminal behavior.
export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1

# Performance: Disable nonessential network traffic at startup.
#
# Eliminates these background network requests:
#   - Telemetry collection (anonymous usage stats)
#   - Automatic version update checks
#   - Error reporting to Anthropic
#   - Bug command functionality
#
# Impact: Reduces startup time from ~4.5s to ~3.0s (30% faster, saves ~1.5s)
#
# Primary benefit is reducing process exit overhead. The Bun runtime waits for
# in-flight network requests to complete before terminating, which previously
# added 3-5s to shutdown. With this flag, exit overhead drops to ~0.5s.
#
# Trade-off: Must manually check for updates with `claude --version` and report
# bugs manually. This is acceptable for the significant performance improvement.
#
# Related optimizations (applied outside this repo):
#   - Removed signoz MCP server (unreachable endpoint caused timeouts)
#   - Switched Linear MCP from npx to globally-installed mcp-remote
#   - Aggressive ~/.claude/ cleanup (2.3GB → 845MB, improves I/O)
#
# See: /Users/mknopf/.claude/docs/notes/session-2026-01-27-claude-code-startup-optimization.md
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
