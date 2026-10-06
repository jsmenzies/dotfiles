#!/usr/bin/env bash
# Shared utilities for dotfiles install scripts

# Auto-detect script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$SCRIPT_DIR")}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Message functions
error()   { echo -e "${RED}✗${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn()    { echo -e "${YELLOW}!${NC} $1"; }
info()    { echo -e "${BLUE}::${NC} $1"; }
header()  { echo; echo -e "${BLUE}$1${NC}"; echo; }

# Platform scripts should set these before running install flow:
# - PLATFORM_NAME
# - PLATFORM_DEPENDENCIES ("name:type", type: required|optional|special)
# - optional platform_check_special <dep>
# - optional PLATFORM_SYMLINKS_EXTRA
PLATFORM_NAME="${PLATFORM_NAME:-unknown}"
PLATFORM_DEPENDENCIES=()
PLATFORM_SYMLINKS_EXTRA=()
SYNLINKS=()

# Get version for a command
# Each command has different output format, handled individually
get_version() {
    local cmd="$1"
    local version=""
    
    case "$cmd" in
        git)
            version=$(git --version 2>/dev/null | cut -d' ' -f3)
            ;;
        brew)
            version=$(brew --version 2>/dev/null | head -n1 | cut -d' ' -f2)
            ;;
        fzf)
            version=$(fzf --version 2>/dev/null | cut -d' ' -f1)
            ;;
        starship)
            version=$(starship --version 2>/dev/null | head -n1 | awk '{print $2}')
            ;;
        zoxide)
            version=$(zoxide --version 2>/dev/null | awk '{print $2}')
            ;;
        eza)
            version=$(eza --version 2>/dev/null | sed -n '2p' | awk '{print $1}' | sed 's/^v//')
            ;;
        op)
            version=$(op --version 2>/dev/null)
            ;;
        orbstack)
            version=$(orbstack version 2>/dev/null | head -n1)
            ;;
        jq)
            version=$(jq --version 2>/dev/null | sed 's/^jq-//')
            ;;
        mise)
            version=$(mise --version 2>/dev/null | head -n1 | awk '{print $1}')
            ;;
        gh)
            version=$(gh --version 2>/dev/null | head -n1 | cut -d' ' -f3)
            ;;
        aws)
            version=$(aws --version 2>/dev/null | cut -d' ' -f1 | cut -d'/' -f2)
            ;;
    esac
    
    echo "$version"
}

verify_xdg() {
    header "Verifying XDG Base Directory specification"

    local xdg_vars=(
        "XDG_CONFIG_HOME"
        "XDG_CACHE_HOME"
        "XDG_DATA_HOME"
        "XDG_STATE_HOME"
    )

    local all_set=true
    local var

    for var in "${xdg_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            error "$var is not set"
            all_set=false
        else
            success "$var=${!var}"
        fi
    done

    echo

    if $all_set; then
        success "All XDG directories are properly configured"
        return 0
    fi

    error "Some XDG directories are missing"
    warn "Please ensure your shell environment sets these variables before running the install script."
    warn "They should be defined in your .zshenv or equivalent shell configuration file."
    return 1
}

ensure_xdg_defaults() {
    if [[ -z "$XDG_CONFIG_HOME" ]]; then
        export XDG_CONFIG_HOME="$HOME/.config"
        info "Defaulted XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
    fi

    if [[ -z "$XDG_CACHE_HOME" ]]; then
        export XDG_CACHE_HOME="$HOME/.cache"
        info "Defaulted XDG_CACHE_HOME=$XDG_CACHE_HOME"
    fi

    if [[ -z "$XDG_DATA_HOME" ]]; then
        export XDG_DATA_HOME="$HOME/.local/share"
        info "Defaulted XDG_DATA_HOME=$XDG_DATA_HOME"
    fi

    if [[ -z "$XDG_STATE_HOME" ]]; then
        export XDG_STATE_HOME="$HOME/.local/state"
        info "Defaulted XDG_STATE_HOME=$XDG_STATE_HOME"
    fi
}

build_symlink_list() {
    SYNLINKS=(
        "zsh/main.zshenv:$HOME/.zshenv"
        "zsh/.zshenv:$XDG_CONFIG_HOME/zsh/.zshenv"
        "zsh/.zprofile:$XDG_CONFIG_HOME/zsh/.zprofile"
        "zsh/.zshrc:$XDG_CONFIG_HOME/zsh/.zshrc"
        "zsh/shared.zprofile:$XDG_CONFIG_HOME/zsh/shared.zprofile"
        "zsh/shared.zshrc:$XDG_CONFIG_HOME/zsh/shared.zshrc"
        "zsh/platform/mac.zprofile:$XDG_CONFIG_HOME/zsh/platform/mac.zprofile"
        "zsh/platform/linux.zprofile:$XDG_CONFIG_HOME/zsh/platform/linux.zprofile"
        "zsh/platform/mac.zshrc:$XDG_CONFIG_HOME/zsh/platform/mac.zshrc"
        "zsh/platform/linux.zshrc:$XDG_CONFIG_HOME/zsh/platform/linux.zshrc"
        "zsh/.zsh_plugins.txt:$XDG_CONFIG_HOME/zsh/.zsh_plugins.txt"
        "zsh/aliases.zsh:$XDG_CONFIG_HOME/zsh/aliases.zsh"
        "zsh/functions.zsh:$XDG_CONFIG_HOME/zsh/functions.zsh"
        "git/.gitconfig:$XDG_CONFIG_HOME/git/config"
        "starship/starship.toml:$XDG_CONFIG_HOME/starship.toml"
        "ghostty/config:$XDG_CONFIG_HOME/ghostty/config"
        "opencode/ghostty.json:$XDG_CONFIG_HOME/opencode/themes/ghostty.json"
        "opencode/opencode.json:$XDG_CONFIG_HOME/opencode/opencode.json"
        "pi/settings.json:$XDG_CONFIG_HOME/pi/agent/settings.json"
        "pi/themes:$XDG_CONFIG_HOME/pi/agent/themes"
        "pi/extensions:$XDG_CONFIG_HOME/pi/agent/extensions"
        "pi/mcp.json:$XDG_CONFIG_HOME/pi/agent/mcp.json"
        "skillshare/global.yaml:$XDG_CONFIG_HOME/skillshare/config.yaml"
        "claude/statusline.sh:$XDG_CONFIG_HOME/claude/statusline.sh"
        "aws/config:$HOME/.aws/config"
    )

    if [[ ${#PLATFORM_SYMLINKS_EXTRA[@]} -gt 0 ]]; then
        SYNLINKS+=("${PLATFORM_SYMLINKS_EXTRA[@]}")
    fi
}

# Create symlinks based on SYNLINKS configuration
create_symlinks() {
    local dry_run="${1:-false}"
    local backup_dir="${2:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"
    local dotfiles_dir="${3:-$(dirname "$SCRIPT_DIR")}"

    for link in "${SYNLINKS[@]}"; do
        IFS=':' read -r source target <<< "$link"
        local source_path="$dotfiles_dir/$source"

        if [[ ! -e "$source_path" ]]; then
            warn "Source missing, skipping: $source"
            continue
        fi
        
        # Already correctly linked
        if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source_path" ]]; then
            success "Already linked: $target"
            continue
        fi
        
        if [[ "$dry_run" == "true" ]]; then
            if [[ -e "$target" && ! -L "$target" ]]; then
                info "[dry-run] Would back up: $target -> $backup_dir/"
            fi

            if [[ -L "$target" ]]; then
                info "[dry-run] Would remove symlink: $target"
            fi

            info "[dry-run] Would link: $source_path -> $target"
            continue
        fi

        # Create parent directory only when installing
        mkdir -p "$(dirname "$target")"

        # Backup existing file (not symlink)
        if [[ -e "$target" && ! -L "$target" ]]; then
            mkdir -p "$backup_dir"
            mv "$target" "$backup_dir/"
            warn "Backed up: $target"
        fi

        # Remove incorrect symlink
        [[ -L "$target" ]] && rm "$target"

        # Create symlink
        ln -s "$source_path" "$target"
        success "Linked: $target"
    done
    
    if [[ -d "$backup_dir" ]]; then
        info "Backups: $backup_dir"
    fi
}

# Merge claude/statusline.json into Claude Code's settings. settings.json is
# rewritten by Claude Code and other tools, so only the statusLine key is managed.
configure_claude_statusline() {
    local dry_run="${1:-false}"
    local dotfiles_dir="${2:-$(dirname "$SCRIPT_DIR")}"
    local source_path="$dotfiles_dir/claude/statusline.json"
    local settings="$XDG_CONFIG_HOME/claude/settings.json"

    if ! command -v jq >/dev/null 2>&1; then
        warn "jq not found, skipping Claude status line config"
        return 0
    fi

    if [[ -f "$settings" ]] && jq -e --slurpfile want "$source_path" \
        '.statusLine == $want[0]' "$settings" >/dev/null 2>&1; then
        success "Already configured: Claude status line"
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        info "[dry-run] Would set statusLine in $settings"
        return 0
    fi

    mkdir -p "$(dirname "$settings")"
    [[ -f "$settings" ]] || echo '{}' > "$settings"

    local tmp
    tmp=$(mktemp)
    if jq --slurpfile want "$source_path" '.statusLine = $want[0]' "$settings" > "$tmp"; then
        mv "$tmp" "$settings"
        success "Configured: Claude status line"
    else
        rm -f "$tmp"
        warn "Failed to update $settings"
    fi
}

check_command_dep() {
    local cmd="$1"
    local dep_type="$2"

    if command -v "$cmd" >/dev/null 2>&1; then
        local version
        version=$(get_version "$cmd")

        if [[ -n "$version" ]]; then
            success "$cmd v$version"
        else
            success "$cmd"
        fi
    else
        if [[ "$dep_type" == "required" ]]; then
            error "$cmd - NOT FOUND"
            MISSING_REQUIRED+=("$cmd")
        else
            warn "$cmd - NOT FOUND"
            MISSING_OPTIONAL+=("$cmd")
        fi
    fi
}

check_special_dep() {
    local dep="$1"

    if declare -F platform_check_special >/dev/null 2>&1; then
        platform_check_special "$dep"
    else
        warn "$dep - No platform special checker configured"
        MISSING_OPTIONAL+=("$dep")
    fi
}

verify_dependencies() {
    local heading="Verifying dependencies"
    if [[ -n "$PLATFORM_NAME" && "$PLATFORM_NAME" != "unknown" ]]; then
        heading="Verifying dependencies (${PLATFORM_NAME})"
    fi
    header "$heading"

    MISSING_REQUIRED=()
    MISSING_OPTIONAL=()

    local dep_spec dep dep_type
    for dep_spec in "${PLATFORM_DEPENDENCIES[@]}"; do
        IFS=':' read -r dep dep_type <<< "$dep_spec"

        case "$dep_type" in
            special)
                check_special_dep "$dep"
                ;;
            required)
                check_command_dep "$dep" required
                ;;
            optional)
                check_command_dep "$dep" optional
                ;;
            *)
                warn "$dep - Unknown dependency type: $dep_type"
                ;;
        esac
    done

    echo

    if [[ ${#MISSING_REQUIRED[@]} -eq 0 ]]; then
        success "All required dependencies are installed"

        if [[ ${#MISSING_OPTIONAL[@]} -gt 0 ]]; then
            info "Optional dependencies missing: ${MISSING_OPTIONAL[*]}"
        fi

        return 0
    fi

    error "Missing required dependencies: ${MISSING_REQUIRED[*]}"
    return 1
}

run_install() {
    local dry_run="${1:-false}"
    local backup_dir="${2:-$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)}"

    ensure_xdg_defaults
    info "Verifying XDG directories..."
    verify_xdg

    if [[ -n "$PLATFORM_NAME" && "$PLATFORM_NAME" != "unknown" ]]; then
        header "Installing dotfiles (${PLATFORM_NAME})"
    else
        header "Installing dotfiles"
    fi

    build_symlink_list
    create_symlinks "$dry_run" "$backup_dir" "$DOTFILES_DIR"
    configure_claude_statusline "$dry_run" "$DOTFILES_DIR"
    verify_dependencies
}
