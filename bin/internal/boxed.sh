#!/usr/bin/env zsh

# Output ascii art box with text to clipboard (for section headers)
# Usage: boxed.sh "Text"

# Example:

echo "$1" \
    | boxes -d shell -s 80 -a c -i none \
    | pbcopy
