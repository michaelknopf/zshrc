
export VOLTA_HOME="$HOME/.volta"

alias p=pnpm

# Performance: Cache pnpm completion to avoid ~117ms eval on every shell startup
# The cached file is automatically loaded by compinit via fpath in zsh.sh
# Regenerate with: pnpm completion zsh > ~/.zsh/completions/_pnpm
[[ -f "$ZSH_COMPLETIONS_DIR/_pnpm" ]] || pnpm completion zsh > "$ZSH_COMPLETIONS_DIR/_pnpm"

alias pup="pnpm update --latest"
