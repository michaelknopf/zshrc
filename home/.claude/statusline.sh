#!/usr/bin/env zsh
# Claude Code status line: Display model name and session cost
#
# Performance optimization: Reduced from 4 process spawns to 1.
#
# Previous implementation (4 processes):
#   model_name=$(cat | jq -r '.model.display_name')
#   total_cost=$(cat | jq -r '.cost.total_cost_usd')
#   rounded_cost=$(echo "$total_cost * 100" | bc | awk '{printf "%.0f", $0}')
#   final_cost=$(echo "scale=2; $rounded_cost / 100" | bc)
#   echo "[$model_name] 💰 \$$final_cost"
#
# New implementation (1 process):
#   - jq reads from stdin (no cat)
#   - jq does arithmetic natively (no bc or awk)
#   - jq does string interpolation directly (no echo)
#
# Impact: Minimal on overall startup (~10ms saved), but eliminates wasteful
# process creation on every status line render. Part of broader optimization
# effort that reduced total startup time from 10-12s to 3-4s.

jq -r '"[\(.model.display_name)] 💰 $\(.cost.total_cost_usd * 100 | floor / 100)"'
