#!/usr/bin/env zsh
set -euo pipefail

# Host process for Remote Control sessions started from the Claude desktop and
# mobile apps. Sessions it spawns run on this machine, so they get the real
# filesystem, ~/.claude config, plugins, MCP servers and local CLIs -- none of
# which a cloud session has.
#
# launchd starts this at login and restarts it if it dies, so the host is not
# something to keep a terminal tab open for. Sessions it hosts die with it.

# launchd gives us no login-shell environment. Sessions spawn MCP servers by
# bare name (mcp-grafana, npx), so they need the same PATH an interactive shell has.
ZSHRC_ROOT="${0:A:h:h:h}"
source "$ZSHRC_ROOT/zshrc.d/path.sh"

# Sessions inherit this cwd. The apps can open other directories; this is only
# where a session lands when it names none.
cd "$HOME/code/github/savi"

exec claude rc \
  --permission-mode bypassPermissions \
  --remote-control-session-name-prefix "$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
