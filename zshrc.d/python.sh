# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

alias vnv="virtualenv -p "$(pyenv which python)" .venv"
alias acv="source activate_venv.sh"
