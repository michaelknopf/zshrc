#!/usr/bin/env zsh
jq -r '"[\(.model.display_name)] 💰 $\(.cost.total_cost_usd * 100 | floor / 100)"'
