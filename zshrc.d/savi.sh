#compdef savi-login

_savi_login_completion() {
  eval $(env _TYPER_COMPLETE_ARGS="${words[1,$CURRENT]}" _SAVI_LOGIN_COMPLETE=complete_zsh savi-login)
}

compdef _savi_login_completion savi-login
