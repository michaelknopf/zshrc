#!/usr/bin/env zsh
set -euo pipefail

# Update all Claude Code marketplaces and plugins.
#
# Both stages are network-bound and the CLI updates each target serially, so we
# fan out one process per marketplace and per plugin. Each job's output is
# buffered to a temp file and printed only after all jobs in the stage finish,
# keeping per-target logs contiguous instead of interleaved. Any failed job
# makes the whole script exit non-zero.

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# run_parallel <stage-name> <tab-separated lines on stdin> <command template...>
# Each input line is split on tabs into positional args $1, $2, ... which the
# job body references. Returns non-zero if any job failed.
run_parallel() {
    local stage=$1; shift
    local stagedir="$tmpdir/$stage"
    mkdir -p "$stagedir"

    local -a pids=()
    local i=0 line
    while IFS= read -r line; do
        local -a fields=("${(@s:	:)line}")  # split on tab
        (
            local label=${fields[1]}
            if out=$("$@" "${fields[@]}" 2>&1); then
                printf 'OK   %s\n%s\n' "$label" "$out"
            else
                printf 'FAIL %s\n%s\n' "$label" "$out"
                exit 1
            fi
        ) >"$stagedir/$i.log" 2>&1 &
        pids+=($!)
        ((++i))
    done

    local failed=0 pid
    for pid in "${pids[@]}"; do
        wait "$pid" || failed=1
    done
    local f
    for f in "$stagedir"/*.log(N); do
        cat "$f"
    done
    return $failed
}

update_marketplace() { claude plugin marketplace update "$1"; }
update_plugin()      { claude plugin update --scope "$2" "$1"; }

overall=0

echo "Updating marketplaces in parallel..."
# One field per line: the marketplace name (also used as the log label).
claude plugin marketplace list --json | jq -r '.[].name' \
    | run_parallel marketplaces update_marketplace || overall=1

echo "\nUpdating installed plugins in parallel..."
# Two tab-separated fields: id (label + $1) and scope ($2). Scope matters
# because `claude plugin update` defaults to --scope user and fails for plugins
# installed at other scopes (project, local, managed).
claude plugin list --json | jq -r '.[] | "\(.id)\t\(.scope)"' \
    | run_parallel plugins update_plugin || overall=1

if (( overall )); then
    echo "\nSome updates FAILED (see above)." >&2
    exit 1
fi

echo "\nAll marketplaces and plugins updated successfully!"
