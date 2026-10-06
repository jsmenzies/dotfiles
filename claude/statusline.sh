#!/bin/bash
# Claude Code status line, styled after starship/starship.toml:
#   ~/git/prhq on  main [ ] via ✻ Opus 5.5 (high) at ▰▰▱▱▱ 38% in  #212

input=$(cat)

# Keep Orca's status line hook fed, if it's installed.
orca_hook="$HOME/.orca/agent-hooks/claude-statusline.sh"
if [[ -r "$orca_hook" ]]; then
    (printf '%s' "$input" | /bin/sh "$orca_hook" >/dev/null 2>&1 &)
fi

# Named ANSI colours, same as starship, so the terminal theme applies
reset=$'\e[0m'
bold=$'\e[1m'
dim=$'\e[2m'
red=$'\e[31m'
green=$'\e[32m'
yellow=$'\e[33m'
blue=$'\e[34m'
purple=$'\e[35m'
cyan=$'\e[36m'
claude=$'\e[38;2;217;119;87m'

# Nerd Font glyphs (bash 3.2 has no \u escapes)
branch_icon=$'\xee\x82\xa0'   # U+E0A0
untracked_icon=$'\xef\x94\xa9' # U+F529
modified_icon=$'\xef\x81\x84'  # U+F044
pr_icon=$'\xef\x90\x87'        # U+F407

IFS=$'\t' read -r cwd model effort ctx_pct pr_num pr_url pr_state < <(jq -r '[
    (.workspace.current_dir // .cwd),
    (.model.display_name // .model.id),
    .effort.level,
    .context_window.used_percentage,
    .pr.number, .pr.url, .pr.review_state
] | map(. // "" | tostring) | @tsv' <<<"$input")

out=""

# directory: green up to the repo root, bold green root, bold cyan beyond it
display=${cwd/#$HOME/\~}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$root" ]]; then
    root_disp=${root/#$HOME/\~}
    out+="${green}${root_disp%/*}/${bold}${root_disp##*/}${reset}"
    rest=${display#"$root_disp"}
    [[ -n "$rest" ]] && out+="${bold}${cyan}${rest}${reset}"
else
    out+="${bold}${cyan}${display}${reset}"
fi

# git branch + status
branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
if [[ -n "$branch" ]]; then
    (( ${#branch} > 16 )) && branch="${branch:0:16}…"
    out+=" on ${bold}${purple}${branch_icon} ${branch}${reset}"

    status=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    flags=""
    grep -q '^??' <<<"$status" && flags+=" ${untracked_icon}"
    grep -q '^.[MD]' <<<"$status" && flags+=" ${modified_icon}"
    staged=$(grep -c '^[MADRC]' <<<"$status")
    (( staged > 0 )) && flags+=" ${green}++(${staged})${red}"
    [[ -n "$flags" ]] && out+=" ${bold}${red}[${flags} ]${reset}"
fi

# model + effort
if [[ -n "$model" ]]; then
    # Claude's spinner glyphs, one frame per refresh (refreshInterval: 1)
    frames=(· ✢ ✳ ✶ ✻ ✽ ✻ ✶ ✳ ✢)
    spinner=${frames[$(( $(date +%s) % ${#frames[@]} ))]}
    out+=" via ${bold}${claude}${spinner} ${model}${reset}"

    if [[ -n "$effort" ]]; then
        case "$effort" in
            low) colour=$dim ;;
            medium) colour=$cyan ;;
            high) colour=$yellow ;;
            *) colour=$red ;;
        esac
        out+=" ${dim}(${reset}${colour}${effort}${reset}${dim})${reset}"
    fi
fi

# context usage
if [[ -n "$ctx_pct" ]]; then
    pct=${ctx_pct%.*}
    if (( pct >= 80 )); then colour=$red
    elif (( pct >= 50 )); then colour=$yellow
    else colour=$green
    fi
    filled=$(( (pct + 10) / 20 ))
    (( filled > 5 )) && filled=5
    bar=""
    for ((i = 0; i < 5; i++)); do
        if (( i < filled )); then bar+="▰"; else bar+="▱"; fi
    done
    out+=" at ${bold}${colour}${bar} ${pct}%${reset}"
fi

# pull request, as a clickable OSC 8 link
if [[ -n "$pr_num" ]]; then
    case "$pr_state" in
        approved) colour=$green ;;
        changes_requested) colour=$red ;;
        draft) colour=$dim ;;
        *) colour=$blue ;;
    esac
    link_open=$'\e]8;;'"${pr_url}"$'\e\\'
    link_close=$'\e]8;;\e\\'
    out+=" in ${link_open}${bold}${colour}${pr_icon} #${pr_num}${reset}${link_close}"
fi

printf '%s' "$out"
