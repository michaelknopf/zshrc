# PATH initialization for zsh
# - Builds PATH from an array and exports it as a colon-delimited string
# - Idempotent: will not re-run if already initialized in this shell session
# - Provides a helper to pretty-print PATH

export PNPM_HOME="/Users/mknopf/Library/pnpm"

# Define desired PATH entries. Customize as needed.
# Note: Use zsh array semantics and later join with ':'
typeset -ga ZSHRC_PATH_ARRAY
ZSHRC_PATH_ARRAY=(
    "$ZSHRC_ROOT/bin"       # this repo's bin folder
    "$HOME/.local/bin"
    "$HOME/bin"
    "/opt/homebrew/bin"     # macOS (Apple Silicon Homebrew)
    "/usr/local/bin"        # macOS (Intel Homebrew) / common
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin",
    "$HOME/.volta/bin"
    "$PNPM_HOME"
    "$HOME/fvm/default/bin"
)

# Merge existing PATH entries (split by ':'), appending those not already present
# This preserves order: first our preferred paths, then any remaining from existing PATH.
# zsh split flag: (@s/:/) splits $PATH into an array by ':'
typeset -a _zshrc_existing_path_array
_zshrc_existing_path_array=( "${(@s/:/)PATH}" )

for _p in ${_zshrc_existing_path_array[@]}; do
    # Skip empty entries and duplicates
    if [[ -n "${_p}" ]] && (( ${ZSHRC_PATH_ARRAY[(Ie)${_p}]} == 0 )); then
        ZSHRC_PATH_ARRAY+=( "${_p}" )
    fi
done

# Join array into colon-delimited string and export
export PATH="${(j.:.)ZSHRC_PATH_ARRAY}"

# Pretty print function for PATH
# Usage: pp_path
pp_path() {
    local -a _arr
    _arr=( "${(@s/:/)PATH}" )
    local i=1
    for _e in ${_arr[@]}; do
        printf "%2d) %s\n" $i "${_e}"
        (( i++ ))
    done
}
