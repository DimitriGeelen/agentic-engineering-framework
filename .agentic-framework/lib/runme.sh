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
#   fw runme pending   (session start: WATCH LOST / RUN IN FLIGHT / RUN ENDED WITHOUT RECORD, T-3878)
#
# Exit codes: new 0 / 2 usage; watch = the script's exit code, 124 on timeout.

_runme_root() { echo "${PROJECT_ROOT:-$(pwd)}/.context/runme"; }

# T-3767: a leading '-' is never a name — `fw runme watch --help` used to wait
# 30 min for a runme called "--help".
_runme_valid_name() { [[ "$1" =~ ^[A-Za-z0-9._][A-Za-z0-9._-]*$ ]]; }

_runme_usage() { sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

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

# T-3878: the nearest ancestor of PID whose command line is claude (the session
# that armed a watch), or nothing.
_runme_claude_ancestor() {
    local p="${1:-$$}" i=0
    while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null && [ "$i" -lt 30 ]; do
        if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -qE '(^|/)claude( |$)'; then
            echo "$p"; return 0
        fi
        p=$(awk '{print $4}' "/proc/$p/stat" 2>/dev/null); i=$((i + 1))
    done
    return 0
}

_runme_alive() { [ -n "${1:-}" ] && [ "$1" != null ] && kill -0 "$1" 2>/dev/null; }

runme_watch() {
    local name="${1:-}"; shift || true
    local timeout=1800
    while [ $# -gt 0 ]; do
        case "$1" in --timeout) timeout="$2"; shift 2 ;; *) echo "runme watch: unexpected '$1'" >&2; return 2 ;; esac
    done
    _runme_valid_name "$name" || { echo "runme watch: bad name" >&2; return 2; }
    local log; log="$(_runme_root)/$name/run.log"
    # T-3878: record WHO armed this watch. A watch dies with the session that
    # armed it; at the next session start `fw runme pending` reads this record
    # and says WATCH LOST instead of leaving the operator's run unobserved.
    local rec; rec="$(_runme_root)/$name/watch.json"
    mkdir -p "$(dirname "$rec")"
    printf '{"watch_pid": %s, "arming_claude_pid": %s, "armed_at": "%s"}\n' \
        "$$" "$(_runme_claude_ancestor "$$" | grep . || echo null)" "$(date -u +%FT%TZ)" > "$rec"
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
    rm -f "$rec"   # T-3878: reported — nothing left to re-arm
    local rc; rc=$(grep -o "RUNME EXIT [0-9]*" "$log" | tail -1 | awk '{print $3}')
    return "${rc:-1}"
}

# T-3878: handed-over runmes that need attention at session start.
#   WATCH LOST              a watch was armed, the run has no EXIT, and the
#                           arming claude or the watcher is gone
#   RUN IN FLIGHT           START without EXIT and runme.sh is still running
#   RUN ENDED WITHOUT RECORD  START without EXIT and nothing runs it (killed,
#                           reboot: the EXIT trap never fired)
# Only runmes touched in the last 7 days. Exit 0 always.
runme_pending() {
    local root; root="$(_runme_root)"
    local found=0 d name log rec wpid cpid running
    [ -d "$root" ] || { echo "runme: nothing pending"; return 0; }
    while IFS= read -r d; do
        name=$(basename "$d"); log="$d/run.log"; rec="$d/watch.json"
        [ -f "$d/runme.sh" ] || continue
        grep -q "RUNME EXIT" "$log" 2>/dev/null && { rm -f "$rec"; continue; }
        running=""
        pgrep -f "$d/runme.sh" >/dev/null 2>&1 && running=1
        if grep -q "RUNME START" "$log" 2>/dev/null; then
            if [ -n "$running" ]; then
                echo "RUN IN FLIGHT  $name — started, no EXIT yet; watch it: fw runme watch $name"
            else
                echo "RUN ENDED WITHOUT RECORD  $name — started, no EXIT, nothing runs it (killed or rebooted?); read $log and ask the operator"
            fi
            found=1
        fi
        if [ -f "$rec" ]; then
            wpid=$(sed -n 's/.*"watch_pid": *\([0-9]*\).*/\1/p' "$rec")
            cpid=$(sed -n 's/.*"arming_claude_pid": *\([0-9]*\).*/\1/p' "$rec")
            if ! _runme_alive "$wpid" || { [ -n "$cpid" ] && ! _runme_alive "$cpid"; }; then
                echo "WATCH LOST  $name — the session that armed it is gone; re-arm: fw runme watch $name"
                found=1
            fi
        fi
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -mtime -7 2>/dev/null | sort)
    [ "$found" = 1 ] || echo "runme: nothing pending"
    return 0
}

runme_main() {
    local sub="${1:-}"; shift || true
    case "${1:-}" in -h|--help) _runme_usage; return 0 ;; esac
    case "$sub" in
        new) runme_new "$@" ;;
        watch) runme_watch "$@" ;;
        pending) runme_pending ;;
        path) _runme_valid_name "${1:-}" && echo "$(_runme_root)/$1/runme.sh" ;;
        ""|-h|--help|help) _runme_usage ;;
        *) echo "fw runme: unknown subcommand '$sub' (new|watch|pending|path)" >&2; return 2 ;;
    esac
}
