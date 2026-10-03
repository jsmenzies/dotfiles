#!/usr/bin/env bash

PLATFORM_NAME="mac"

PLATFORM_DEPENDENCIES=(
    "git:required"
    "brew:required"
    "fzf:required"
    "starship:required"
    "zoxide:required"
    "eza:required"
    "mise:required"
    "aws:optional"
    "antidote:special"
    "op:optional"
    "orbstack:optional"
    "gh:optional"
    "gh-dash:special"
    "1password-agent:special"
)

PLATFORM_SYMLINKS_EXTRA=()

platform_check_special() {
    local dep="$1"

    case "$dep" in
        antidote)
            if brew list antidote &>/dev/null; then
                local version
                version=$(brew info antidote --json 2>/dev/null | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
                if [[ -n "$version" ]]; then
                    success "antidote v$version"
                else
                    success "antidote"
                fi
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
        gh-dash)
            if gh extension list 2>/dev/null | grep -q "gh-dash"; then
                success "gh-dash"
            else
                warn "gh-dash - NOT FOUND (install: gh extension install dlvhdr/gh-dash)"
                MISSING_OPTIONAL+=("gh-dash")
            fi
            ;;
        *)
            warn "$dep - Unknown special dependency"
            MISSING_OPTIONAL+=("$dep")
            ;;
    esac
}
