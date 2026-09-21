#!/usr/bin/env zsh
set -euo pipefail

# Host process for Remote Control sessions started from the Claude mobile app or
# claude.ai. Sessions it spawns run on this machine, so they get the real
# filesystem, ~/.claude config, plugins, MCP servers and local CLIs -- none of
# which a cloud session has.
#
# The Claude desktop app does NOT route through this host; it spawns its own
# local process per session. This host is only what remote clients reach.
#
# launchd starts this at login and restarts it if it dies, so the host is not
# something to keep a terminal tab open for. Sessions it was serving do not die
# with it -- see the --continue call below.

# launchd gives us no login-shell environment, so PATH must be built here.
# ~/.local/bin/claude is a symlink into a version-pinned directory that moves on
# every update; resolving through PATH at exec time keeps this correct.
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# Sessions inherit this cwd. The apps can open other directories; this is only
# where a session lands when it names none.
cd "$HOME/code/github/savi"

HOST_PREFIX="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"

# Sessions a stopped host was serving stay unarchived and reattachable for about
# four hours, so a restart within that window should reclaim them rather than
# come up empty. --continue exits 1 when there is nothing recorded here, which is
# the normal case at a cold login; falling through to a plain start keeps
# KeepAlive from turning that into a restart loop.
claude rc --continue --permission-mode bypassPermissions \
  --remote-control-session-name-prefix "$HOST_PREFIX" && exit 0

echo "claude-rc-host: no session to continue, starting fresh" >&2
exec claude rc --permission-mode bypassPermissions \
  --remote-control-session-name-prefix "$HOST_PREFIX"
