#!/bin/zsh
set -euo pipefail

# Simple setup script to symlink your zsh files to this repository.
# It links:
#   ~/.zshrc  -> <repo>/zshrc.sh
#   ~/.zshenv -> <repo>/zshenv.sh

export ZSHRC_ROOT="$HOME/code/github/zshrc"

link_file() {
    # link_file <target> <link_name>
    local target="$1"
    local link_name="$2"

    # Create or update the symlink atomically and forcefully
    ln -sfn "$target" "$link_name"
    echo "Linked $link_name -> $target"
}

main() {
    link_file "$ZSHRC_ROOT/zshrc.sh" "$HOME/.zshrc"
    link_file "$ZSHRC_ROOT/zshenv.sh" "$HOME/.zshenv"
    echo "Done. Open a new shell or run: source ~/.zshrc"
}

main "$@"
