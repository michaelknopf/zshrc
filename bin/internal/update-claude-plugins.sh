#!/usr/bin/env zsh
set -euo pipefail

# Update all Claude Code marketplaces and plugins

echo "Updating all marketplaces..."
claude plugin marketplace update

echo "\nUpdating installed plugins..."
# Parse 'claude plugin list --json' to extract plugin IDs
claude plugin list --json | jq -r '.[].id' | while read -r plugin; do
    echo "Updating $plugin..."
    claude plugin update "$plugin"
done

echo "\nAll marketplaces and plugins updated successfully!"
