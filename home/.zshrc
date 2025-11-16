# ~/.zshrc is symlinked to this file

export ZSHRC_ROOT="$HOME/code/github/michaelknopf/zshrc"

# Path to your Oh My Zsh installation (override here if not default)
export ZSH="${ZSH-"$HOME/.oh-my-zsh"}"

# Files to source in order from zshrc.d
ZSHRC_SOURCE_FILES=(
    "path.sh"        # Initialize PATH first
    "zsh.sh"         # Zsh completions, etc.
    "oh_my_zsh.sh"   # Load Oh My Zsh
    "git.sh"         # Git aliases (optional)
    "direnv.sh"
    "python.sh"
    "go.sh"
    "node.sh"
    "ngrok.sh"
    "aider.sh"
    "terraform.sh"
    "twilio.sh"
    "overmind.sh"
    "claude.sh"
    "ruby.sh"
    "savi.sh"
    "private.sh"
)

for _f in "${ZSHRC_SOURCE_FILES[@]}"; do
    source "$ZSHRC_ROOT/zshrc.d/$_f"
done

alias szsh="source ~/.zshrc"

autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terragrunt terragrunt

fpath+=~/.zfunc; autoload -Uz compinit; compinit

zstyle ':completion:*' menu select
