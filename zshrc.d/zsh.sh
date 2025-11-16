export ZSH_COMPLETIONS_DIR="$HOME/.zsh/completions"

# Add custom completions directory
fpath=("$ZSH_COMPLETIONS_DIR" $fpath)

# Enable completion system if not already
autoload -Uz compinit
compinit
