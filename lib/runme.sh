#!/bin/bash
# lib/runme.sh — operator command handoff as ONE line (T-3675, operator ruling 2026-10-01).
#
# When the operator has to run something, the agent does not paste a multi-line block.
# It writes .context/runme/<name>/runme.sh, prints `bash /abs/path/runme.sh`, and then
# watches .context/runme/<name>/run.log. The script tees every line, timestamped, to
# that log and brackets it with START / EXIT <code> markers, so the agent can read
# exactly what happened without the operator copying output back.
#
#   fw runme new <name> [--desc "..."] -- <command> [<command> ...]
#       each <command> is one shell line; a single '-' reads lines from stdin
#   fw runme watch <name> [--timeout SECS]   (default 1800; waits for START, then EXIT)
#   fw runme path <name>
#
# Exit codes: new 0 / 2 usage; watch = the script's exit code, 124 on timeout.

_runme_root() { echo "${PROJECT_ROOT:-$(pwd)}/.context/runme"; }

_runme_valid_name() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]]; }

runme_new() {
    local name="${1:-}"; shift || true
    local desc=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --desc) desc="$2"; shift 2 ;;
            --) shift; break ;;
            *) echo "runme new: unexpected '$1' (commands go after --)" >&2; return 2 ;;
        esac
    done
    if [ -z "$name" ] || ! _runme_valid_name "$name"; then
        echo "runme new: need a name matching [A-Za-z0-9._-]+" >&2; return 2
    fi
    local -a cmds=()
    if [ "$#" -eq 1 ] && [ "$1" = "-" ]; then
        while IFS= read -r line; do cmds+=("$line"); done
    else
        cmds=("$@")
    fi
    [ "${#cmds[@]}" -gt 0 ] || { echo "runme new: no commands given" >&2; return 2; }

    local dir; dir="$(_runme_root)/$name"
    mkdir -p "$dir"
    local script="$dir/runme.sh" log="$dir/run.log"
    {
        echo '#!/bin/bash'
        echo "# runme: $name — generated $(date -u +%FT%TZ) by fw runme (T-3675)"
        [ -n "$desc" ] && echo "# $desc"
        echo "LOG='$log'"
        echo ': > "$LOG"'
        echo 'exec > >(while IFS= read -r l; do printf "%s %s\n" "$(date +%T)" "$l"; done | tee -a "$LOG") 2>&1'
        echo 'echo "RUNME START '"$name"' $(date -u +%FT%TZ) user=$(id -un) host=$(hostname)"'
        echo 'trap '"'"'rc=$?; echo "RUNME EXIT $rc"; sleep 0.3'"'"' EXIT'
        echo 'set -euo pipefail'
        local c
        for c in "${cmds[@]}"; do
            printf 'echo "+ %s"\n' "$(printf '%s' "$c" | sed 's/[\\"$`]/\\&/g')"
            printf '%s\n' "$c"
        done
    } > "$script"
    chmod 755 "$script"
    echo "Run this (one line, copy-paste):"
    echo
    echo "  bash $script"
    echo
    echo "Log: $log"
}

runme_watch() {
    local name="${1:-}"; shift || true
    local timeout=1800
    while [ $# -gt 0 ]; do
        case "$1" in --timeout) timeout="$2"; shift 2 ;; *) echo "runme watch: unexpected '$1'" >&2; return 2 ;; esac
    done
    _runme_valid_name "$name" || { echo "runme watch: bad name" >&2; return 2; }
    local log; log="$(_runme_root)/$name/run.log"
    local waited=0
    until [ -f "$log" ] && grep -q "RUNME START" "$log" 2>/dev/null; do
        [ "$waited" -ge "$timeout" ] && { echo "runme watch: not started within ${timeout}s"; return 124; }
        sleep 2; waited=$((waited + 2))
    done
    echo "runme watch: $name started"
    until grep -q "RUNME EXIT" "$log" 2>/dev/null; do
        [ "$waited" -ge "$timeout" ] && { echo "runme watch: still running after ${timeout}s"; tail -n 20 "$log"; return 124; }
        sleep 2; waited=$((waited + 2))
    done
    cat "$log"
    local rc; rc=$(grep -o "RUNME EXIT [0-9]*" "$log" | tail -1 | awk '{print $3}')
    return "${rc:-1}"
}

runme_main() {
    local sub="${1:-}"; shift || true
    case "$sub" in
        new) runme_new "$@" ;;
        watch) runme_watch "$@" ;;
        path) _runme_valid_name "${1:-}" && echo "$(_runme_root)/$1/runme.sh" ;;
        ""|-h|--help|help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
        *) echo "fw runme: unknown subcommand '$sub' (new|watch|path)" >&2; return 2 ;;
    esac
}
