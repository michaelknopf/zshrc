#!/bin/zsh
set -euo pipefail

# Install VSCode extensions from vscode/extensions.txt.
# Idempotent: only installs extensions not already present.
#
# Usage:
#   ./scripts/vscode-extensions.sh           # install missing extensions
#   ./scripts/vscode-extensions.sh --prune   # also uninstall unlisted extensions

ZSHRC_ROOT="${ZSHRC_ROOT:-$HOME/code/github/michaelknopf/zshrc}"
EXTENSIONS_FILE="$ZSHRC_ROOT/vscode/extensions.txt"

if ! command -v code &>/dev/null; then
    echo "Error: 'code' CLI not found."
    echo "Install it from VSCode: Cmd+Shift+P → 'Shell Command: Install code command in PATH'"
    exit 1
fi

# Parse extension IDs: strip comments, blank lines, and whitespace; lowercase for comparison
wanted=()
while IFS= read -r line; do
    line="${line%%#*}"
    line="${line// /}"
    [[ -z "$line" ]] && continue
    wanted+=("${line:l}")
done < "$EXTENSIONS_FILE"

installed=("${(@f)$(code --list-extensions | tr '[:upper:]' '[:lower:]')}")

for ext in "${wanted[@]}"; do
    if (( ${installed[(Ie)$ext]} )); then
        echo "Already installed: $ext"
    else
        echo "Installing: $ext"
        code --install-extension "$ext" --force
    fi
done

# Optional: remove extensions not in the list
if [[ "${1:-}" == "--prune" ]]; then
    for ext in "${installed[@]}"; do
        if (( ! ${wanted[(Ie)$ext]} )); then
            echo "Removing (not in extensions.txt): $ext"
            code --uninstall-extension "$ext"
        fi
    done
fi

echo "Done."
