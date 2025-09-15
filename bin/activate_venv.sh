#!/usr/bin/env zsh
# acv - Activate closest venv or .venv going up the directory tree

function activate {
    d="$PWD"
    while [ "$d" != "/" ]; do
        if [ -d "$d/venv" ]; then
            . "$d/venv/bin/activate"
            return 0
        elif [ -d "$d/.venv" ]; then
            . "$d/.venv/bin/activate"
            return 0
        fi
        d=$(dirname "$d")
    done

    echo "No venv or .venv found"
    return 1
}

activate
