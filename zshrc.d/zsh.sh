# Add custom completions directory
fpath=($HOME/.zsh/completions $fpath)

# Enable completion system if not already
autoload -Uz compinit
compinit
