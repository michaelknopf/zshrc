#!/bin/zsh
set -euo pipefail

# Simple setup script to symlink your zsh files to this repository.
# It links:
#   ~/.zshrc  -> <repo>/zshrc.sh
#   ~/.zshenv -> <repo>/zshenv.sh

export ZSHRC_ROOT="$HOME/code/github/michaelknopf/zshrc"

link_file() {
    # link_file <target> <link_name>
    local target="$1"
    local link_name="$2"

    # Create or update the symlink atomically and forcefully
    ln -sfn "$target" "$link_name"
    echo "Linked $link_name -> $target"
}

link_claude() {
    link_file "$ZSHRC_ROOT/claude/settings.json" "$HOME/.claude/settings.json"
}

link_aider() {
    link_file "$ZSHRC_ROOT/aider/aider.conf.yml" "$HOME/.aider.conf.yml"
}

link_direnv() {
    link_file "$ZSHRC_ROOT/direnv/direnv.toml" "$HOME/.config/direnv/direnv.toml"
}

link_junie() {
    link_file "$ZSHRC_ROOT/junie" "$HOME/.junie"
}

link_aws() {
    link_file "$ZSHRC_ROOT/aws" "$HOME/.aws"
}

link_ngrok() {
    link_file "$ZSHRC_ROOT/ngrok/ngrok.yml" "$HOME/Library/Application Support/ngrok/ngrok.yml"
}

link_zshrc() {
    link_file "$ZSHRC_ROOT/zshrc.sh" "$HOME/.zshrc"
    link_file "$ZSHRC_ROOT/zshenv.sh" "$HOME/.zshenv"
    echo "Done. Open a new shell or run: source ~/.zshrc"
}

link_claude
link_aider
link_direnv
link_junie
link_aws
link_ngrok
link_zshrc
