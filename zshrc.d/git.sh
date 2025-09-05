alias gph="git push -u origin HEAD"

# overwrites alias for 'git commit -v -a'
alias gca="git commit --amend --no-edit"

alias gp='git pull --recurse-submodules'

alias gcp="gaa && gca && gpf"

alias gdh="git diff HEAD"

alias grh="git reset --hard"

alias cdroot='cd $(git rev-parse --show-toplevel 2>/dev/null || echo ".")'
