autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

alias tf=tofu
alias tg=terragrunt

alias tga='terragrunt apply -auto-approve'

export TG_NON_INTERACTIVE=true

# Shared caches to avoid per-stack duplication of providers and module
# downloads. The provider cache itself is configured in ~/.terraformrc
# (see home/.terraformrc in this repo); we just ensure the directory exists
# so `terraform init` doesn't error on first use.
mkdir -p "$HOME/.terraform.d/plugin-cache"

# Redirect Terragrunt's per-stack `.terragrunt-cache/` dirs to a single global
# location. Without this, each `live/<stack>/` gets its own copy of the
# rendered module source plus its own `.terraform/` (compounding with the
# provider cache savings above).
export TERRAGRUNT_DOWNLOAD="$HOME/.cache/terragrunt"
mkdir -p "$TERRAGRUNT_DOWNLOAD"
