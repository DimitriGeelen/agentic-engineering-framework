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
    fw_conversation_continue_id "$cwd" "${PROJECT_ROOT:-$cwd}"
    return 0
}

# T-4497: what `-c` should mean under claude-fw. Bare `claude -c` continues the
# NEWEST conversation in the folder, and every `claude -p` worker (fw termlink
# dispatch) writes a newer one: -c was refused while the worker ran, and once it
# ended it RESUMED THE WORKER'S TRANSCRIPT as if it were the agent (055 T-586,
# 1409-sprind 2026-10-20). A worker's transcript records entrypoint "sdk-cli"
# (sdk-*); an interactive one "cli".
#
# fw_conversation_record_file <project_root> — where claude-fw records the
# conversation it ran (per project, beside the other session state).
fw_conversation_record_file() {
    echo "$1/.context/working/.claude-fw-conversation"
}

# fw_conversation_continue_id <cwd> [project_root] [candidate] — the conversation
# to continue: <candidate> (default: the recorded id) when its transcript is here and interactive, else the
# newest interactive transcript in <cwd>'s folder, else nothing. Never a worker.
fw_conversation_continue_id() {
    local cwd="$1" root="${2:-$1}" rec="${3:-}"
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" enc
    enc=$(printf '%s' "$cwd" | sed 's/[^A-Za-z0-9-]/-/g')
    [ -z "$rec" ] && [ -f "$(fw_conversation_record_file "$root")" ] && rec=$(head -1 "$(fw_conversation_record_file "$root")" 2>/dev/null)
    python3 - "$cfg/projects/$enc" "$rec" <<'PY' 2>/dev/null
import json, os, re, sys
d, rec = sys.argv[1], sys.argv[2].strip()

def worker(path):
    # The first entrypoint in the transcript header decides; none = interactive.
    try:
        with open(path, errors="replace") as f:
            for i, line in enumerate(f):
                if i >= 50:
                    break
                try:
                    ep = json.loads(line).get("entrypoint")
                except Exception:
                    continue
                if isinstance(ep, str) and ep:
                    return ep.startswith("sdk")
    except OSError:
        return True
    return False

if rec and re.fullmatch(r"[A-Za-z0-9._-]+", rec):
    p = os.path.join(d, rec + ".jsonl")
    if os.path.isfile(p) and not worker(p):
        print(rec)
        sys.exit(0)
try:
    names = [n for n in os.listdir(d) if n.endswith(".jsonl")]
except OSError:
    sys.exit(0)
paths = sorted((os.path.join(d, n) for n in names), key=lambda p: os.path.getmtime(p), reverse=True)
for p in paths:
    if not worker(p):
        print(os.path.basename(p)[:-6])
        break
PY
    return 0
}

# fw_conversation_record <cwd> <project_root> <since_epoch> [launched_id] — after
# a run, record the interactive conversation it wrote: the newest interactive
# transcript touched since <since_epoch>, else <launched_id>. Silent no-op when
# there is nowhere to write it. Return 0 always.
fw_conversation_record() {
    local cwd="$1" root="$2" since="$3" launched="${4:-}" id f
    [ -d "$root/.context/working" ] || return 0
    local cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" enc
    enc=$(printf '%s' "$cwd" | sed 's/[^A-Za-z0-9-]/-/g')
    # The launched conversation first, when this run wrote to it (a second
    # interactive session in the same folder must not steal the record).
    if [ -n "$launched" ] && [ -f "$cfg/projects/$enc/$launched.jsonl" ] \
        && [ "$(stat -c %Y "$cfg/projects/$enc/$launched.jsonl" 2>/dev/null || echo 0)" -ge "$since" ] \
        && [ "$(fw_conversation_continue_id "$cwd" "/nonexistent" "$launched")" = "$launched" ]; then
        id="$launched"
    else
        id=$(fw_conversation_continue_id "$cwd" "/nonexistent")
        if [ -n "$id" ]; then
            f="$cfg/projects/$enc/$id.jsonl"
            [ "$(stat -c %Y "$f" 2>/dev/null || echo 0)" -ge "$since" ] || id=""
        fi
        [ -n "$id" ] || id="$launched"
    fi
    [ -n "$id" ] || return 0
    printf '%s\n' "$id" > "$(fw_conversation_record_file "$root")" 2>/dev/null || true
    return 0
}

# fw_conversation_rewrite_continue <cwd> <project_root> <args...> — print the args
# NUL-separated with every -c/--continue replaced by `--resume <id>` (T-4497), or
# dropped when no interactive conversation exists (a fresh session rather than a
# worker's transcript). Other args pass through unchanged.
fw_conversation_rewrite_continue() {
    local cwd="$1" root="$2"; shift 2
    local a id="" resolved=0
    for a in "$@"; do
        case "$a" in
            -c|--continue)
                if [ "$resolved" = 0 ]; then
                    id=$(fw_conversation_continue_id "$cwd" "$root"); resolved=1
                    [ -n "$id" ] && printf '%s\0' --resume "$id"
                fi
                ;;
            *) printf '%s\0' "$a" ;;
        esac
    done
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
