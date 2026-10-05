#!/usr/bin/env bash
# T-3890: never run two live copies of one Claude conversation.
#
# `claude -c` continues the NEWEST conversation in this directory and
# `--resume <id>` a named one. Neither checks whether another live process is
# already in that conversation. 832, 2026-10-05: after a reboot the fleet resumed
# their conversation by id while a separate `claude-fw -c` continued the same
# one; two live copies ran ~2h45 and BOTH executed the upgrade's re-apply step.
#
# Live holder = the sidecar session record (.context/sidecar/sessions/<id>.json,
# written by the prompt/stop hooks) names a claude_pid that is alive AND is
# still a claude process (a recycled pid does not count).

# fw_conversation_target <cwd> <claude args...> — the conversation id the args
# will open, or nothing (a fresh conversation, or undeterminable).
fw_conversation_target() {
    local cwd="$1"; shift
    local mode="" id="" prev=""
    for a in "$@"; do
        case "$prev" in --resume|-r) id="$a"; mode=resume ;; esac
        case "$a" in
            -c|--continue) mode=${mode:-continue} ;;
            --resume=*) id="${a#--resume=}"; mode=resume ;;
        esac
        prev="$a"
    done
    if [ "$mode" = resume ]; then
        [ -n "$id" ] && echo "$id"
        return 0
    fi
    [ "$mode" = continue ] || return 0
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" enc newest
    enc=$(printf '%s' "$cwd" | sed 's/[^A-Za-z0-9-]/-/g')
    newest=$(ls -t "$cfg/projects/$enc/"*.jsonl 2>/dev/null | head -1)
    [ -n "$newest" ] && basename "$newest" .jsonl
    return 0
}

# fw_conversation_holder <project_root> <id> — prints the live holder's pid, or
# nothing. Return 0 always.
fw_conversation_holder() {
    local root="$1" id="$2" rec pid
    [ -n "$id" ] || return 0
    rec="$root/.context/sidecar/sessions/$id.json"
    [ -f "$rec" ] || return 0
    pid=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("claude_pid") or "")' "$rec" 2>/dev/null)
    case "$pid" in ''|*[!0-9]*) return 0 ;; esac
    kill -0 "$pid" 2>/dev/null || return 0
    tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'claude' || return 0
    echo "$pid"
    return 0
}
