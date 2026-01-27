# Performance: Lazy-load rbenv to avoid ~73ms init on every shell startup
# Only initializes when ruby/gem/bundle commands are actually used
if (( $+commands[rbenv] )); then
    rbenv() {
        unfunction rbenv
        eval "$(command rbenv init -)"
        rbenv "$@"
    }
fi
