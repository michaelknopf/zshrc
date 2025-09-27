# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

alias vnv="virtualenv -p "$(pyenv which python)" .venv"
alias acv="source $ZSHRC_ROOT/bin/internal/activate_venv.sh"

# Make pipx use pyenv's global python
export PIPX_DEFAULT_PYTHON="$(
    # Get the first version in the list, since it can contain multiple, e.g. "3.13 3.12"
    first_global=$(pyenv global | awk '{print $1}')
    # Resolve aliases like 3.13 to the actual version, like 3.13.7
    pyenv prefix "$first_global"
)/bin/python"
