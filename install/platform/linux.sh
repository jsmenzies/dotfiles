#!/usr/bin/env bash

PLATFORM_NAME="linux"

PLATFORM_DEPENDENCIES=(
    "git:required"
    "fzf:required"
    "starship:required"
    "zoxide:required"
    "eza:required"
    "mise:required"
    "aws:required"
    "antidote:special"
    "op:optional"
    "gh:optional"
    "jq:optional"
    "1password-agent:special"
)

PLATFORM_SYMLINKS_EXTRA=()

platform_check_special() {
    local dep="$1"

    case "$dep" in
        antidote)
            local antidote_path=""
            if command -v brew >/dev/null 2>&1; then
                antidote_path="$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
            elif [[ -f "/usr/share/antidote/antidote.zsh" ]]; then
                antidote_path="/usr/share/antidote/antidote.zsh"
            elif [[ -f "/usr/local/share/antidote/antidote.zsh" ]]; then
                antidote_path="/usr/local/share/antidote/antidote.zsh"
            elif [[ -n "$XDG_DATA_HOME" && -f "$XDG_DATA_HOME/antidote/antidote.zsh" ]]; then
                antidote_path="$XDG_DATA_HOME/antidote/antidote.zsh"
            elif [[ -f "$HOME/.local/share/antidote/antidote.zsh" ]]; then
                antidote_path="$HOME/.local/share/antidote/antidote.zsh"
            fi

            if [[ -n "$antidote_path" && -f "$antidote_path" ]]; then
                success "antidote"
            else
                error "antidote - NOT FOUND"
                MISSING_REQUIRED+=("antidote")
            fi
            ;;
        1password-agent)
            local socket="$HOME/.1password/agent.sock"
            if [[ -S "$socket" ]]; then
                success "1password-agent"
            else
                warn "1password-agent - NOT FOUND"
                MISSING_OPTIONAL+=("1password-agent")
            fi
            ;;
        *)
            warn "$dep - Unknown special dependency"
            MISSING_OPTIONAL+=("$dep")
            ;;
    esac
}
