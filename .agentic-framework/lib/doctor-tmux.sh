#!/usr/bin/env bash
# lib/doctor-tmux.sh — T-4781
#
# `fw doctor` check: does one tmux server carry claude-fw sessions of more than one
# project? Until T-4781 bin/claude-fw wrapped every project on one shared server
# (`tmux -L fw-agents`), and a bare `tmux kill-server` from any project's pane killed
# every project's agent on the host at once (dimitri-mint-dev T-188/T-190, 2026-10-26).
# claude-fw now starts one server per project (`-L fw-agents-<16 hex>`); this check
# reports any server that still mixes projects (the legacy one, while old sessions
# live on it). WARN only, never blocks.
#
# Read-only: it only runs `tmux -S <socket> list-sessions` on sockets named fw-agents*
# in this user's tmux socket dir — never the default server, never a write.
# Contract (same as lib/doctor-drift.sh): prints `  OK|WARN  …` with the caller's colour
# variables and increments the caller's `warnings` counter.

# doctor_tmux_shared_servers — one line per fw-agents* server with sessions of 2+
# projects: `<socket name> <n projects> <dir1,dir2,...>`. Projects are told apart by the
# <dir> of claude-fw's session names `fw-<dir>-<pid>`.
doctor_tmux_shared_servers() {
    command -v tmux >/dev/null 2>&1 || return 0
    local sdir="${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)" s names dirs n
    [ -d "$sdir" ] || return 0
    for s in "$sdir"/fw-agents*; do
        [ -S "$s" ] || continue
        names=$(tmux -S "$s" list-sessions -F '#{session_name}' 2>/dev/null) || continue
        dirs=$(printf '%s\n' "$names" | sed -n 's/^fw-\(.*\)-[0-9][0-9]*$/\1/p' | sort -u)
        n=$(printf '%s' "$dirs" | grep -c .) || n=0
        [ "$n" -gt 1 ] && printf '%s %s %s\n' "$(basename "$s")" "$n" "$(printf '%s' "$dirs" | paste -sd, -)"
    done
    return 0
}

doctor_check_tmux_sharing() {
    local rows
    rows=$(doctor_tmux_shared_servers)
    if [ -z "$rows" ]; then
        echo -e "  ${GREEN}OK${NC}  claude-fw tmux servers: none shared between projects"
        return 0
    fi
    local sock n dirs
    while read -r sock n dirs; do
        echo -e "  ${YELLOW}WARN${NC}  tmux server '$sock' carries claude-fw sessions of $n projects ($dirs) — a kill-server there takes all of them (T-4781)"
        warnings=$((warnings + 1))
    done <<< "$rows"
    echo "         Fix: end and restart those sessions with claude-fw; each now gets its own server (fw-agents-<project id>)"
}
