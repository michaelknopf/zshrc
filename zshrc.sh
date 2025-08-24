# ~/.zshrc is symlinked to this file

export ZSHRC_ROOT="$HOME/code/github/zshrc"

# Path to your Oh My Zsh installation (override here if not default)
export ZSH="${ZSH-"$HOME/.oh-my-zsh"}"

# Files to source in order from zshrc.d
ZSHRC_SOURCE_FILES=(
    "path.sh"        # Initialize PATH first
    "oh_my_zsh.sh"   # Load Oh My Zsh
    "git.sh"         # Git aliases (optional)
)

for _f in "${ZSHRC_SOURCE_FILES[@]}"; do
    source "$ZSHRC_ROOT/zshrc.d/$_f"
done
