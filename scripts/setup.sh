#!/bin/zsh
set -euo pipefail

# Simple setup script to symlink your zsh files to this repository.
# It links:
#   ~/.zshrc  -> <repo>/home/zshrc.sh
#   ~/.zshenv -> <repo>/home/zshenv.sh
# Also links several other files to your home directory, and sets up some other convenient symlinks.

export ZSHRC_ROOT="$HOME/code/github/michaelknopf/zshrc"

link_file() {
    # link_file <target> <link_name>
    local target="$1"
    local link_name="$2"

    # don't overwrite directories unless FORCE_REPLACE is set
    if [[ -d "$link_name" && ! -L "$link_name" ]]; then
        if [[ "${FORCE_REPLACE:-0}" != "1" ]]; then
            echo "Refusing to replace directory $link_name (set FORCE_REPLACE=1 to override)"
            return 1
        fi
        rm -rf -- "$link_name"
    fi

    ln -sfn "$target" "$link_name"
    echo "Linked $link_name -> $target"
}

link_aider() {
    link_file "$ZSHRC_ROOT/aider/aider.conf.yml" "$HOME/.aider.conf.yml"
}

link_ngrok() {
    link_file "$ZSHRC_ROOT/ngrok/ngrok.yml" "$HOME/Library/Application Support/ngrok/ngrok.yml"
}

link_all_home_files() {
    for src in "$ZSHRC_ROOT"/home/*(N) "$ZSHRC_ROOT"/home/.*(N); do
        base=${src:t}
        [[ $base == . || $base == .. ]] && continue
        link_file "$src" "$HOME/$base"
    done
}

link_all_home_files_recursive() {
    local root="${ZSHRC_ROOT}/home"
    local src rel dest

    [[ -d "$root" ]] || {
        echo "Missing: $root"
        return 1
    }

    # Walk everything; create dirs, link files/symlinks
    find "$root" -mindepth 1 -print0 | while IFS= read -r -d '' src; do
        rel="${src#$root/}"
        dest="$HOME/$rel"

        if [[ -d "$src" && ! -L "$src" ]]; then
            mkdir -p "$dest"
        else
            mkdir -p "${dest:h}"
            link_file "$src" "$dest"
        fi
    done
}

link_aider
link_ngrok
link_all_home_files
echo "Done. Open a new shell or run: source ~/.zshrc"
