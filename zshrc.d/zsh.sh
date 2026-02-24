export ZSH_COMPLETIONS_DIR="$HOME/.zsh/completions"

# Add custom completions directory
fpath=("$HOME/.zfunc" "$ZSH_COMPLETIONS_DIR" $fpath)

# Enable completion system if not already
autoload -Uz compinit
compinit
