autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

alias tf=tofu
alias tg=terragrunt

alias tga='terragrunt apply -auto-approve'

export TG_NON_INTERACTIVE=true
