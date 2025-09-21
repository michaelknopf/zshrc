alias gph="git push -u origin HEAD"

# overwrites alias for 'git commit -v -a'
alias gca="git commit --amend --no-edit"

alias gp='git pull --recurse-submodules'

alias gcp="gaa && gca && gpf"

alias gdh="git diff HEAD"

alias grh="git reset --hard"

alias cdr='cd $(git rev-parse --show-toplevel 2>/dev/null || echo ".")'

alias gbc="git branch | cat"

alias gs="git stash"
alias gsp="git stash pop"

# Updates your local branch main directly to origin/main (fast-forward only).
# Works while you’re on another branch.
alias gfm="git fetch origin && git fetch origin main:main"
