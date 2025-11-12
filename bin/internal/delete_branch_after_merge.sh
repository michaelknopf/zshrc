#!/usr/bin/env zsh
set -euo pipefail

# Delete current branch after merging to main.
# First updates local main from origin, merges main into current branch,
# then checks for any remaining differences before deleting.

# Get current branch
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Validate not already on main
if [[ "$current_branch" == "main" ]]; then
    echo "Error: Already on main branch. Nothing to delete."
    exit 1
fi

echo "Current branch: $current_branch"
echo "Updating main from origin..."

# Checkout main and pull latest
if ! git checkout main; then
    echo "Error: Failed to checkout main"
    exit 1
fi

if ! git pull origin main; then
    echo "Error: Failed to pull main from origin"
    git checkout "$current_branch"  # Try to go back to original branch
    exit 1
fi

echo "Checking out $current_branch and merging main..."

# Checkout back to original branch
if ! git checkout "$current_branch"; then
    echo "Error: Failed to checkout $current_branch"
    exit 1
fi

# Merge main into current branch (no-edit to avoid commit message prompt)
if ! git merge main --no-edit; then
    echo "Error: Failed to merge main into $current_branch"
    echo "Please resolve conflicts and try again."
    exit 1
fi

# Check if there are differences between branch and main
diff_output=$(git diff main...HEAD)

if [[ -n "$diff_output" ]]; then
    echo ""
    echo "WARNING: Branch '$current_branch' has differences from main after merge:"
    echo ""
    git diff main...HEAD --stat
    echo ""
    read "response?Continue with deletion? (y/n): "
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Deletion cancelled."
        exit 0
    fi
fi

echo "Checking out main and deleting $current_branch..."

# Checkout main
if ! git checkout main; then
    echo "Error: Failed to checkout main"
    exit 1
fi

# Force delete the branch
if git branch -D "$current_branch"; then
    echo "Successfully deleted branch: $current_branch"
else
    echo "Error: Failed to delete branch $current_branch"
    exit 1
fi
