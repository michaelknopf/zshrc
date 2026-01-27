
# Loki - https://grafana.com/docs/loki/latest/query/logcli/getting-started/
# Performance: Cache logcli completion to avoid ~44ms eval on every shell startup
# The cached file is automatically loaded by compinit via fpath in zsh.sh
# Regenerate with: logcli --completion-script-zsh > ~/.zsh/completions/_logcli
[[ -f "$ZSH_COMPLETIONS_DIR/_logcli" ]] || logcli --completion-script-zsh > "$ZSH_COMPLETIONS_DIR/_logcli"

export LOKI_ADDR="https://logs-prod-021.grafana.net"
export LOKI_USERNAME="1455179"
