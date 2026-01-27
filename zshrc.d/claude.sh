
# For analytics dashboard:
#   claude-code-templates --analytics

export CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1

# Disable nonessential network traffic (telemetry, auto-updater, error reporting)
# to reduce startup time from ~4.5s to ~3.0s (30% faster)
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
