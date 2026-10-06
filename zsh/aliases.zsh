# ls
alias l &>/dev/null && unalias l
alias l='eza --all --long --icons --color=auto --no-permissions --octal-permissions'

# yolo
alias yolo='git add . && git commit -m "vibing" && git push --set-upstream origin $(git rev-parse --abbrev-ref HEAD)'

# Zsh
alias reload='source $ZDOTDIR/.zshrc'

alias gs='git status'

alias ac='autocommit --add --accept --push'

# OpenCode
alias oc='opencode'
