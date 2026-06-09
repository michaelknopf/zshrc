# iTerm2 session name = the basename of the current git repo's root.
#
# Background: iTerm2's profile "Title" was set to "Session Name" to stop it from
# deriving the tab title from the foreground job. (Previously it latched onto the
# deepest MCP child process and showed `claude (slack-mcp-server-darwin-arm64)`.)
# Now we drive the Session Name ourselves so tabs show a stable, useful label.
#
# Behavior:
#   - Inside a git repo (including any subfolder): basename of the repo root.
#   - In $HOME: "~".
#   - Any other directory: basename of $PWD.
# The name is recomputed on every prompt (precmd), so it stays fixed even while a
# long-running foreground command like `claude` is executing — no process name
# ever leaks back into the title.

# Only do this for interactive iTerm2 sessions; no-op everywhere else.
if [[ -o interactive && "$TERM_PROGRAM" == "iTerm.app" ]]; then

  # Disable Oh My Zsh's auto-title hooks (omz_termsupport_precmd/preexec). The
  # preexec hook is what would swap the title to the running command's name; we
  # want the title to stay pinned to the repo name, so turn the whole thing off.
  export DISABLE_AUTO_TITLE=true

  _iterm_set_session_name() {
    local name root
    root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$root" ]]; then
      name=${root:t}            # repo root basename, e.g. "zshrc"
    elif [[ "$PWD" == "$HOME" ]]; then
      name="~"                  # $PWD:t in $HOME would be the username; prefer "~"
    else
      name=${PWD:t}             # plain folder basename
    fi
    # OSC 0: set both tab and window title. printf (not `print -P`) so a literal
    # "%" in a folder name is never interpreted as a prompt escape.
    printf '\033]0;%s\007' "$name"
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _iterm_set_session_name
fi
