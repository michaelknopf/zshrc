#!/usr/bin/env zsh
set -euo pipefail

# Update all Claude Code marketplaces and plugins

echo "Updating all marketplaces..."
claude plugin marketplace update

echo "\nUpdating installed plugins..."
# Parse 'claude plugin list --json' for each plugin's id and scope, since
# `claude plugin update` defaults to --scope user and fails for plugins
# installed at other scopes (project, local, managed).
claude plugin list --json | jq -r '.[] | "\(.id)\t\(.scope)"' | while IFS=$'\t' read -r plugin scope; do
    echo "Updating $plugin (scope: $scope)..."
    claude plugin update --scope "$scope" "$plugin"
done

echo "\nAll marketplaces and plugins updated successfully!"
