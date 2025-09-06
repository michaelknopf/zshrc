autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

alias tf=tofu
alias tg=terragrunt

export TG_NON_INTERACTIVE=true
