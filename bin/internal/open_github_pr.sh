#!/usr/bin/env zsh
set -euo pipefail

# Find an open PR for the current branch and open it in the browser.

# Get current branch
branch=$(git rev-parse --abbrev-ref HEAD)

# Find an open PR for this branch -> main
pr_url=$(
    gh pr list \
    --head "$branch" \
    --base main \
    --state open \
    --json url \
    -q '.[0].url'
)

if [[ -n "$pr_url" ]]; then
    echo "Opening PR: $pr_url"
    if command -v xdg-open >/dev/null; then
        xdg-open "$pr_url"
    elif command -v open >/dev/null; then
        open "$pr_url"   # macOS
    else
        echo "No known way to open URLs on this system."
        exit 1
    fi
else
    echo "No open PR found for branch '$branch' -> main."
    exit 1
fi
