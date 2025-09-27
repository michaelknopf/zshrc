#!/usr/bin/env zsh

# Read JSON input from stdin
input=$(cat)

# Extract values using jq
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')
COST=$(printf "%.2f" "$COST")

echo "[$MODEL_DISPLAY] 💰 \$${COST}"
