# Performance: Cache ngrok completion to avoid ~19ms eval on every shell startup
# The cached file is automatically loaded by compinit via fpath in zsh.sh
# Regenerate with: ngrok completion > ~/.zsh/completions/_ngrok
[[ -f "$ZSH_COMPLETIONS_DIR/_ngrok" ]] || ngrok completion > "$ZSH_COMPLETIONS_DIR/_ngrok"
