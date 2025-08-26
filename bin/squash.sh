#!/bin/zsh

branch="${1:-main}"

git reset $(git merge-base "$branch" HEAD)
git add -A
git commit
