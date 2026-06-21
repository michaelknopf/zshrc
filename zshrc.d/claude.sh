
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
#   - Feature-flag (GrowthBook) evaluation
#
# Side effect: disabling feature-flag evaluation also disables Remote Control
# (driving this session from the claude.ai web/mobile app), since that feature
# is gated behind a feature flag. `/doctor` will show Remote Control as disabled
# with "disabled by CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC" — this is expected,
# not a bug. To use Remote Control in a one-off session, launch with:
#   env -u CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC claude
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
#
# DISABLED 2026-06-15: This flag turns off GrowthBook feature-flag evaluation, and the
# Channels research-preview feature (used by AIM for session-to-session
# messaging — see the `cl` alias below) is gated behind those flags. With the flag set,
# launching a channel session reports "--dangerously-load-development-channels ignored /
# Channels are not currently available": the channel TOOLS still work, but the inbound
# push direction is dead, so peer messages never reach the session. The same gate also
# disables Remote Control (noted above). Re-enabling feature-flag evaluation (i.e.
# leaving this unset) costs ~1.5s of startup time but is required for channels to work.
# Re-enable the export if you stop using channels/Remote Control and want the speed back.
#export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1

# Use 1m context window with Sonnet by default
#export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-6[1m]'

# Use Bedrock as the provider for Claude Code
alias claude-bedrock='CLAUDE_CODE_USE_BEDROCK=1 ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-6 ANTHROPIC_DEFAULT_SONNET_MODEL=claude-sonnet-4-6 AWS_PROFILE=play-sso-power claude'

# `aim` — start a Claude session wired into AIM (AOL Instant Messenger for AI sessions),
# so it can talk to other `aim` sessions (see ~/code/github/savi/aim).
#
# The `aim` MCP server is registered USER-SCOPED in ~/.claude.json (top-level mcpServers),
# so every session already has the AIM tools (send_to_peer, list_peers, …) — no
# --mcp-config needed here. This alias only adds the launch-time flag that enables the
# INBOUND push direction: --dangerously-load-development-channels server:aim makes peer
# messages arrive as <channel> events. (That's a launch concern, not an MCP-config one,
# which is why it lives on the command line rather than in ~/.claude.json.)
#
# No --dangerously-skip-permissions needed: bypassPermissions is already the default in
# ~/.claude/settings.json. Extra args append, so `aim --resume`, `aim -p '...'`, etc. work.
#
# Pin a fixed name with `AIM_PEER=alice aim` (inherited by the aim-server subprocess).
# Unset, sessions auto-name (brave-fox); rename via the set_name tool.
#
# AIM_STATUSLINE=1 is exported so the status line (mk plugin) shows this session's AIM
# peer name as `aim:<name>`. The status-line lookup is OFF by default everywhere else; only
# `aim` sessions opt in, so plain `claude` sessions never pay the broker-lookup cost. The
# lookup is a single short-timeout curl to the local broker and tolerates any failure.
#
# Channels require GrowthBook feature-flag evaluation, which is why the
# CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC export above is commented out — see that note.
# With that flag set, channels report "not currently available" and inbound peer messages
# silently never reach the session.
#
# Prereq: the broker must be running once: `cd ~/code/github/savi/aim && uv run aim-broker`
# (leave it in a spare terminal). If it isn't up, sessions still start fine — they just log
# a failed registration and get no inbound push until it's running.
#
# SECURITY: any bridged peer message can run tools in your session (bypassPermissions +
# localhost broker, no auth) — keep it local-only.
alias aim='AIM_STATUSLINE=1 claude --dangerously-load-development-channels server:aim'

# Another option is to put this JSON in .claude/settings.json
#"env": {
#    "AWS_REGION": "us-west-2",
#    "CLAUDE_CODE_USE_BEDROCK": "1",
#    "ANTHROPIC_DEFAULT_SONNET_MODEL": "global.anthropic.claude-sonnet-4-6",
#    "ANTHROPIC_DEFAULT_OPUS_MODEL": "global.anthropic.claude-opus-4-6-v1",
#    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "global.anthropic.claude-haiku-4-5-20251001-v1:0"
#},
