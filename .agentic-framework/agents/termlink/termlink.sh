#!/bin/bash
# termlink.sh — Framework wrapper for TermLink cross-terminal communication
#
# Thin wrapper around the `termlink` binary. Adds framework concerns
# (task-tagging, budget checks, cleanup tracking) but delegates all
# real work to the binary. Adapted from tl-dispatch.sh (T-143, tested
# with 3 parallel workers).
#
# TermLink repo: https://onedev.docker.ring20.geelenandcompany.com/termlink
# Install: cargo install --path crates/termlink-cli
#
# Part of: Agentic Engineering Framework (T-503, from T-502 inception)
# shellcheck disable=SC2015 # A && B || true pattern is idiomatic for set -e safety
# shellcheck disable=SC2009 # ps|grep is used for process inspection with context

set -euo pipefail

# Resolve paths for config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/config.sh"
# T-2917: fw_worker_git_identity_env — default git identity for direct
# `fw termlink dispatch` (see cmd_dispatch below).
source "$FRAMEWORK_ROOT/lib/git-identity.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# T-3595: FW_DISPATCH_DIR overrides the worker root (same name lib/dispatch_tokens.py reads),
# so tests can point cleanup at a sandbox instead of the dir live workers keep state in.
DISPATCH_DIR="${FW_DISPATCH_DIR:-/tmp/tl-dispatch}"
TERMLINK_WORKER_TIMEOUT=$(fw_config_int "TERMLINK_WORKER_TIMEOUT" 600)

die() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }

# --- Orchestrator-substrate awareness (T-1643, T-1669) ---

# T-1669 — route_cache.json path (matches /opt/termlink runtime_dir resolution).
_route_cache_path() {
    if [ -n "${TERMLINK_RUNTIME_DIR:-}" ]; then
        echo "${TERMLINK_RUNTIME_DIR}/route-cache.json"
    elif [ -n "${XDG_RUNTIME_DIR:-}" ]; then
        echo "${XDG_RUNTIME_DIR}/termlink/route-cache.json"
    else
        echo "/var/lib/termlink/route-cache.json"
    fi
}

# T-1669 Step 1 — query route_cache for best model for a task_type.
# Echoes "<model>" if a stat exists (highest success_rate, ties broken by
# total volume) or empty when no data / file missing / parse failure.
# Never errors. Pure read; the cache file is JSON written by /opt/termlink hub.
_route_cache_query_best_model() {
    local task_type="$1"
    [ -n "$task_type" ] || return 0
    local cache_file
    cache_file=$(_route_cache_path)
    [ -f "$cache_file" ] || return 0
    python3 - "$cache_file" "$task_type" <<'PY' 2>/dev/null || true
import json, sys
try:
    cache = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
tt = sys.argv[2]
stats = cache.get("model_stats") or {}
best = None
for s in stats.values():
    if s.get("task_type") != tt:
        continue
    succ = s.get("successes", 0)
    fail = s.get("failures", 0)
    total = succ + fail
    if total <= 0:
        continue
    rate = succ / total
    cand = (rate, total, s.get("model"))
    if best is None or cand > best:
        best = cand
if best:
    print(best[2])
PY
}

# _derive_task_type — read the active task's workflow_type from focus.yaml.
# Echoes the derived value (e.g. "build", "inception") or empty if no focus
# or the focused task file cannot be read. Never errors — failures are silent
# (caller treats empty as "no derivation").
_derive_task_type() {
    local project_root="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
    local focus_file="$project_root/.context/working/focus.yaml"
    [ -f "$focus_file" ] || return 0
    local current_task
    current_task=$(awk -F': ' '/^current_task:/ {print $2; exit}' "$focus_file" 2>/dev/null | tr -d ' "')
    [ -n "$current_task" ] && [ "$current_task" != "null" ] || return 0
    local task_file
    task_file=$({ ls "$project_root"/.tasks/{active,completed}/"$current_task"-*.md 2>/dev/null || true; } | head -1)
    [ -n "$task_file" ] && [ -f "$task_file" ] || return 0
    awk -F': ' '/^workflow_type:/ {print $2; exit}' "$task_file" 2>/dev/null | tr -d ' "'
    return 0
}

# _resolve_dispatch_model — when --model not passed, fall back to
# DISPATCH_MODEL_FOR_<TASK_TYPE> then DISPATCH_MODEL_DEFAULT (W3).
# Echoes a single line for backward-compat (model only).
_resolve_dispatch_model() {
    local explicit="$1" task_type="$2"
    if [ -n "$explicit" ]; then
        echo "$explicit"
        return 0
    fi
    if [ -n "$task_type" ]; then
        local key="DISPATCH_MODEL_FOR_$(echo "$task_type" | tr '[:lower:]' '[:upper:]')"
        local v
        v=$(fw_config "$key" "" 2>/dev/null || true)
        if [ -n "$v" ]; then
            echo "$v"
            return 0
        fi
    fi
    fw_config "DISPATCH_MODEL_DEFAULT" "" 2>/dev/null || true
    return 0
}

# _resolve_dispatch_model_and_fallback — returns "<model>|<fallback_used>|<source>".
# Resolution order (T-1669 closes T-1641):
#   1. --model explicit                   → source: "explicit",      fallback_used: false
#   2. route_cache.best_model_for(tt)     → source: "route_cache",   fallback_used: true
#   3. FW_DISPATCH_MODEL_FOR_<TYPE> env   → source: "env-per-type",  fallback_used: true
#   4. FW_DISPATCH_MODEL_DEFAULT env      → source: "env-default",   fallback_used: true
#   5. (none)                             → source: "none",          fallback_used: false  → "||none"
#
# Pre-T-1669 the framework dispatch path did 3+4 only — env-var lookup, no
# learned routing. T-1669 inserts step 2: read route-cache.json (written by
# /opt/termlink hub + this framework's own outcome reports) and pick the
# model with best historical success_rate for the task_type.
# T-1669 Step 2 — record dispatch outcome into route_cache.
# Atomic JSON update (file lock + tmpfile rename) so concurrent dispatches
# from this framework and /opt/termlink hub don't lose updates. Silent on
# permission errors / missing python3 — recording is best-effort, never
# fatal to the dispatch itself.
#
# Key shape mirrors /opt/termlink RouteCache (route_cache.rs):
#   model_stats["<model>:<task_type>"] = {model, task_type, successes,
#                                          failures, last_used}
#
# T-3440: a 4th arg carries the dispatch's close_state ("incomplete" | "closed" |
# "n/a"). An incomplete close is NOT a success — the worker exited 0 with its task
# still started-work — so it lands in `failures`, and exit 0 alone no longer buys a
# success. The literal `incomplete` value is recorded in an append-only sidecar
# (dispatch-close-states.jsonl) rather than as a new ModelStats key: route-cache.json
# is shared with the TermLink hub's Rust RouteCache and its field set is pinned by
# tests/fixtures/termlink-route-cache-schema.json (T-1650). New file, no reader broken.
_route_cache_record_outcome() {
    local model="$1" task_type="$2" exit_code="$3" close_state="${4:-}" task="${5:-}"
    [ -n "$model" ] && [ -n "$task_type" ] && [ -n "$exit_code" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0
    local cache_file
    cache_file=$(_route_cache_path)
    local cache_dir
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir" 2>/dev/null || return 0
    [ -w "$cache_dir" ] || return 0
    python3 - "$cache_file" "$model" "$task_type" "$exit_code" "$close_state" "$task" <<'PY' 2>/dev/null || true
import fcntl, json, os, sys, tempfile
from datetime import datetime, timezone

cache_file, model, task_type, exit_code = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
)
close_state = sys.argv[5] if len(sys.argv) > 5 else ""
task = sys.argv[6] if len(sys.argv) > 6 else ""
key = f"{model}:{task_type}"
incomplete = (close_state == "incomplete")
ok = (exit_code == "0") and not incomplete

# T-3440 sidecar: the outcome VALUE, uncollapsed, in a file only we read.
if close_state:
    try:
        side = os.path.join(os.path.dirname(cache_file) or ".",
                            "dispatch-close-states.jsonl")
        with open(side, "a") as f:
            f.write(json.dumps({
                "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "model": model, "task_type": task_type, "task": task,
                "exit_code": exit_code, "close_state": close_state,
                "outcome": ("incomplete" if incomplete
                            else ("success" if ok else "failure")),
            }) + "\n")
    except Exception:
        pass

lock_path = cache_file + ".lock"
lock_fd = open(lock_path, "w")
try:
    fcntl.flock(lock_fd, fcntl.LOCK_EX)
    cache = {"entries": {}, "model_stats": {}}
    if os.path.exists(cache_file):
        try:
            with open(cache_file) as f:
                loaded = json.load(f)
            if isinstance(loaded, dict):
                cache = loaded
        except Exception:
            pass  # corrupt → reset
    if not isinstance(cache.get("model_stats"), dict):
        cache["model_stats"] = {}
    if not isinstance(cache.get("entries"), dict):
        cache["entries"] = {}
    stat = cache["model_stats"].get(key)
    if not isinstance(stat, dict):
        stat = {
            "model": model, "task_type": task_type,
            "successes": 0, "failures": 0, "last_used": None,
        }
    if ok:
        stat["successes"] = int(stat.get("successes", 0) or 0) + 1
    else:
        stat["failures"] = int(stat.get("failures", 0) or 0) + 1
    stat["model"] = model
    stat["task_type"] = task_type
    stat["last_used"] = datetime.now(timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )
    cache["model_stats"][key] = stat

    cache_dir = os.path.dirname(cache_file) or "."
    fd, tmp = tempfile.mkstemp(dir=cache_dir, prefix=".route-cache-", suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(cache, f, indent=2)
        os.replace(tmp, cache_file)
    except Exception:
        try: os.unlink(tmp)
        except Exception: pass
        raise
finally:
    try: fcntl.flock(lock_fd, fcntl.LOCK_UN)
    except Exception: pass
    lock_fd.close()
PY
}

_resolve_dispatch_model_and_fallback() {
    local explicit="$1" task_type="$2"
    if [ -n "$explicit" ]; then
        echo "${explicit}|false|explicit"
        return 0
    fi
    if [ -n "$task_type" ]; then
        local cached
        cached=$(_route_cache_query_best_model "$task_type" 2>/dev/null || true)
        if [ -n "$cached" ]; then
            echo "${cached}|true|route_cache"
            return 0
        fi
        local key="DISPATCH_MODEL_FOR_$(echo "$task_type" | tr '[:lower:]' '[:upper:]')"
        local v
        v=$(fw_config "$key" "" 2>/dev/null || true)
        if [ -n "$v" ]; then
            echo "${v}|true|env-per-type"
            return 0
        fi
    fi
    local d
    d=$(fw_config "DISPATCH_MODEL_DEFAULT" "" 2>/dev/null || true)
    if [ -n "$d" ]; then
        echo "${d}|true|env-default"
    else
        echo "||none"
    fi
    return 0
}

# --- Prerequisite check ---

ensure_termlink() {
    command -v termlink >/dev/null 2>&1 || die "termlink not found on PATH
  Install: git clone https://onedev.docker.ring20.geelenandcompany.com/termlink && cd termlink && cargo install --path crates/termlink-cli"
}

# --- Platform detection ---

is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }

# --- Subcommands ---

# T-3424: hub-store parity. Two stores can coexist on one host (the systemd
# hub's /var/lib/termlink and `termlink mcp serve`'s default /tmp/termlink-0)
# and a post into the wrong one returns an offset and reads straight back —
# indistinguishable from delivery. Counts do not discriminate (the /tmp store
# is BUSY with session events; 1409-sprind measured 118 event topics there vs
# 43 on the fleet hub). MEMBERSHIP does: a known fleet channel exists only on
# the canonical store. So: (1) the MCP config must name the runtime dir the
# running hub uses; (2) the CLI's store must resolve agent-chat-arc.
_check_hub_store_parity() {
    local project_root="${PROJECT_ROOT:-$(pwd)}"
    local mcp="$project_root/.mcp.json"
    local hub_pid hub_dir cfg_dir
    hub_pid=$(pgrep -f "termlink hub start" 2>/dev/null | head -1)
    if [ -n "$hub_pid" ] && [ -r "/proc/$hub_pid/environ" ]; then
        hub_dir=$(tr '\0' '\n' < "/proc/$hub_pid/environ" 2>/dev/null | sed -n 's/^TERMLINK_RUNTIME_DIR=//p' | head -1)
    fi
    if [ -f "$mcp" ]; then
        cfg_dir=$(python3 -c "import json,sys; c=json.load(open(sys.argv[1])); print((c.get('mcpServers',{}).get('termlink',{}).get('env') or {}).get('TERMLINK_RUNTIME_DIR',''))" "$mcp" 2>/dev/null)
        if [ -z "$cfg_dir" ]; then
            echo -e "${YELLOW}WARN${NC}  .mcp.json termlink server sets no TERMLINK_RUNTIME_DIR — MCP channel tools default to /tmp/termlink-0, a store the fleet does not read (T-3424)"
            [ -n "$hub_dir" ] && echo "  Running hub (pid $hub_pid) uses: $hub_dir — set that in .mcp.json env"
        elif [ -n "$hub_dir" ] && [ "$cfg_dir" != "$hub_dir" ]; then
            echo -e "${YELLOW}WARN${NC}  .mcp.json TERMLINK_RUNTIME_DIR=$cfg_dir but the running hub (pid $hub_pid) uses $hub_dir — MCP posts land in a different store (T-3424)"
        else
            echo "  Hub store: ${cfg_dir}${hub_dir:+ (matches running hub pid $hub_pid)}"
        fi
    fi
    # Membership, not count: the fleet channel must resolve on the CLI's store.
    if termlink channel list 2>/dev/null | grep -q "agent-chat-arc"; then
        echo "  Fleet channel agent-chat-arc: present on the CLI's store"
    else
        echo -e "${YELLOW}WARN${NC}  agent-chat-arc is NOT on the store the CLI resolves — posts from here will not reach the fleet (T-3424)"
    fi
}

cmd_check() {
    if command -v termlink >/dev/null 2>&1; then
        local version
        version=$(termlink --version 2>/dev/null | head -1)
        echo -e "${GREEN}OK${NC}  TermLink installed: $version"
        echo "  Path: $(command -v termlink)"
        echo "  Repo: https://onedev.docker.ring20.geelenandcompany.com/termlink"
        _check_hub_store_parity
        return 0
    else
        echo -e "${YELLOW}WARN${NC}  TermLink not installed"
        echo "  Repo: https://onedev.docker.ring20.geelenandcompany.com/termlink"
        echo "  Install: git clone <repo> && cd termlink && cargo install --path crates/termlink-cli"
        return 1
    fi
}

cmd_spawn() {
    ensure_termlink
    local task="" name="" task_type=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --task-type) task_type="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [ -z "$name" ] && name="worker-$(date +%s)"

    # T-1643/W2: derive task_type from active-task workflow_type when omitted.
    if [ -z "$task_type" ]; then
        task_type=$(_derive_task_type)
    fi

    local wdir="$DISPATCH_DIR/$name"
    mkdir -p "$wdir"
    [ -n "$task" ] && echo "$task" > "$wdir/task"

    # Delegate to termlink spawn — it handles platform detection, shell init
    # timing, and wait-for-registration natively. (GH #9: the old code
    # reimplemented these primitives and introduced two bugs.)
    local spawn_args=(--name "$name" --wait --wait-timeout 30)
    # T-1654: canonical tag prefix is `task:` (colon), per
    # tests/fixtures/termlink-list-schema.json + T-1649 audit. Older code
    # produced `task=` (equals) which trips the orchestrator-arc tag-format
    # drift warning the framework emits against itself.
    local tags=""
    [ -n "$task" ] && tags="task:$task"
    if [ -n "$task_type" ]; then
        [ -n "$tags" ] && tags="$tags,task-type:$task_type" || tags="task-type:$task_type"
    fi
    [ -n "$tags" ] && spawn_args+=(--tags "$tags")
    spawn_args+=(--shell)

    termlink spawn "${spawn_args[@]}"
    echo -e "${GREEN}OK${NC}  Session '$name' registered"
    [ -n "$task" ] && echo "  Tagged: $task"
    [ -n "$task_type" ] && echo "  Task-type: $task_type"
}

cmd_exec() {
    ensure_termlink
    local session="${1:-}"
    shift || true
    local command_str="$*"

    [ -z "$session" ] && die "Usage: fw termlink exec <session> <command>"
    [ -z "$command_str" ] && die "Usage: fw termlink exec <session> <command>"

    # Delegate to termlink interact --json (the star primitive)
    termlink interact "$session" "$command_str" --json 2>/dev/null \
        || die "Failed to execute command in session '$session'"
}

cmd_status() {
    ensure_termlink

    echo -e "${BOLD}=== TermLink Sessions ===${NC}"

    # Show dispatch workers with status (adapted from tl-dispatch.sh cmd_status)
    if [ -d "$DISPATCH_DIR" ]; then
        for wdir in "$DISPATCH_DIR"/*/; do
            [ -d "$wdir" ] || continue
            local name
            name=$(basename "$wdir")
            local status="running"
            if [ -f "$wdir/exit_code" ]; then
                local ec
                ec=$(cat "$wdir/exit_code")
                [ "$ec" = "0" ] && status="complete" || status="failed (exit: $ec)"
            fi
            local session_alive="no"
            termlink list 2>/dev/null | grep -q "$name" && session_alive="yes" || true
            local task_tag=""
            [ -f "$wdir/task" ] && task_tag=" [$(cat "$wdir/task")]"
            # T-3440: exit 0 is not the whole story — surface whether the task
            # the worker was dispatched for actually reached a close.
            local close_tag=""
            if [ -f "$wdir/close_state" ]; then
                local cs
                cs=$(cat "$wdir/close_state" 2>/dev/null)
                [ "$cs" = "n/a" ] || close_tag="  close: $cs"
            fi
            printf "  %-20s  status: %-20s  session: %s%s%s\n" "$name" "$status" "$session_alive" "$task_tag" "$close_tag"
        done
        echo ""
    fi

    # Show all TermLink sessions
    echo "All TermLink sessions:"
    termlink list 2>/dev/null || echo "  None"
}

cmd_cleanup() {
    local orphan_count=0 removed_count=0 kept_count=0

    [ -d "$DISPATCH_DIR" ] || {
        echo "No dispatch workers to clean up."
        command -v termlink >/dev/null 2>&1 && termlink clean 2>/dev/null || true
        return 0
    }

    # T-3595: decide per worker, delete per worker. This used to end in
    # `rm -rf "$DISPATCH_DIR"`, which took the dirs of the ACTIVE workers it had just
    # skipped (result, exit_code, meta, completion signing). Only dirs listed in
    # $remove are ever deleted: finished (exit_code present) or orphaned-and-terminated.
    local remove=()
    for wdir in "$DISPATCH_DIR"/*/; do
        [ -d "$wdir" ] || continue
        local wname
        wname=$(basename "$wdir")

        # Finished workers. T-3580 round 7 (codex MEDIUM-3): a REVIEW worker is finished only
        # once its runtime has finalised it — `exit_code` is written BEFORE the completion is
        # signed, so deleting in that window destroyed the result and the signing. Same test
        # `_worker_done` applies for `fw termlink wait`.
        if [ -f "$wdir/exit_code" ]; then
            if _worker_done "$wdir"; then
                remove+=("$wdir")
            else
                echo -e "${YELLOW}KEPT${NC}    Worker '$wname' exited but its review completion is not finalised yet — not removed"
                kept_count=$((kept_count + 1))
            fi
            continue
        fi

        # T-577: Detect and kill orphaned dispatch processes
        # An orphan = dispatch worker dir exists, no exit_code file, but process may still run
        # This catches processes left behind by termlink run timeout (upstream bug) or crashes
        local worker_pids=""
        worker_pids=$(ps aux 2>/dev/null | grep -F "$wdir" | grep -v grep | awk '{print $2}' || true)

        if [ -z "$worker_pids" ]; then
            # No exit_code and no process: crashed, or still being set up by cmd_dispatch.
            # Not provably finished, so it is kept (T-3595).
            echo -e "${YELLOW}KEPT${NC}    Worker '$wname' has no exit_code and no process — not removed"
            kept_count=$((kept_count + 1))
            continue
        fi

        # T-843/T-972: Check if a worker process is actively running — if so, skip (not orphaned)
        # Must check BOTH the matched PIDs AND their child processes, because
        # run.sh (matched by grep $wdir) spawns claude -p as a child process
        # whose args don't contain $wdir. T-3595: the ollama-loop worker kind runs
        # tools/ollama-tool-loop.py instead of claude — that is active too.
        local active_re='claude|ollama-tool-loop'
        local has_worker=false
        for pid in $worker_pids; do
            local cmd_line
            cmd_line=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
            if echo "$cmd_line" | grep -qE "$active_re"; then
                has_worker=true
                break
            fi
            # T-972: Also check child processes of this PID
            local child_pids
            child_pids=$(ps --ppid "$pid" -o pid= 2>/dev/null || true)
            for cpid in $child_pids; do
                local child_cmd
                child_cmd=$(ps -p "$cpid" -o args= 2>/dev/null || echo "")
                if echo "$child_cmd" | grep -qE "$active_re"; then
                    has_worker=true
                    break 2
                fi
            done
        done

        if [ "$has_worker" = true ]; then
            echo -e "${GREEN}ACTIVE${NC}  Worker '$wname' has running worker process — skipping"
            kept_count=$((kept_count + 1))
            continue
        fi

        echo -e "${YELLOW}ORPHAN${NC}  Worker '$wname' has running processes without TermLink session"
        for pid in $worker_pids; do
            local cmd_line
            cmd_line=$(ps -p "$pid" -o args= 2>/dev/null || echo "unknown")
            echo "  PID $pid: $cmd_line"
            kill "$pid" 2>/dev/null && echo "  -> Sent SIGTERM to $pid" || true
        done
        orphan_count=$((orphan_count + 1))
        remove+=("$wdir")
    done

    [ "$orphan_count" -gt 0 ] && echo -e "${YELLOW}Cleaned $orphan_count orphaned worker(s)${NC}"

    # Collect tracked window IDs (macOS only) — of removed workers only: phase 1 below
    # kill -9's everything on the window's TTY, which would take an active worker with it.
    local window_ids=""
    local wdir
    for wdir in "${remove[@]}"; do
        [ -f "$wdir/window_id" ] && window_ids="${window_ids:+$window_ids }$(cat "$wdir/window_id")"
    done

    # Deregister stale TermLink sessions
    command -v termlink >/dev/null 2>&1 && termlink clean 2>/dev/null || true

    # 3-phase Terminal cleanup (T-074/T-143 — NEVER close directly)
    if is_macos && [ -n "$window_ids" ]; then
        # Phase 1: Kill child processes via TTY (spare login/shell PID)
        for wid in $window_ids; do
            local tty
            tty=$(osascript -e "tell application \"Terminal\" to try
                return tty of tab 1 of window id $wid
            end try" 2>/dev/null || true)
            if [ -n "$tty" ]; then
                ps -t "${tty#/dev/}" -o pid=,comm= 2>/dev/null \
                    | grep -v -E '(login|-zsh|-bash)' \
                    | awk '{print $1}' | xargs kill -9 2>/dev/null || true
            fi
        done
        sleep 2

        # Phase 2: Exit shells gracefully
        for wid in $window_ids; do
            osascript -e "tell application \"Terminal\" to try
                do script \"exit\" in window id $wid
            end try" 2>/dev/null || true
        done
        sleep 2

        # Phase 3: Close remaining windows by tracked reference
        if [ -n "$window_ids" ]; then
            local id_list=""
            for wid in $window_ids; do
                id_list="${id_list:+$id_list, }$wid"
            done
            osascript -e "tell application \"Terminal\"
                set targetIds to {$id_list}
                repeat with w in (reverse of (windows as list))
                    try
                        if (id of w) is in targetIds then close w
                    end try
                end repeat
            end tell" 2>/dev/null || true
        fi
    fi

    for wdir in "${remove[@]}"; do
        rm -rf "$wdir" && removed_count=$((removed_count + 1))
    done
    # The top-level dir goes only when nothing is left in it.
    rmdir "$DISPATCH_DIR" 2>/dev/null || true

    local summary="Cleaned up $removed_count worker(s)"
    [ "$orphan_count" -gt 0 ] && summary="$summary ($orphan_count orphan(s) terminated)"
    [ "$kept_count" -gt 0 ] && summary="$summary; kept $kept_count"
    echo "$summary."
}

# T-3580 round 3: the worker kinds `dispatch --worker-kind` accepts, printed by
# `fw termlink worker-kinds` so a caller (fw reviewer judge) learns what can actually be
# dispatched instead of hardcoding it. Must match the case statement in cmd_dispatch
# (pinned by tests/unit/t3580_round3_test.py).
# T-3582: codex (openai), opencode (zai) and antigravity (google) are HARNESS kinds — review-only,
# run read-only in a `git archive` export of the reviewed revision, launched by the binary and
# model policy/review-backends.yaml commits, their printed verdict recorded by the runtime
# (lib/verdict_ledger.py HARNESS_KINDS, record-for-worker). See docs/harnesses.md.
DISPATCH_WORKER_KINDS="claude ollama-loop codex opencode antigravity"

# T-3580 round 7 (Claude F2): the ONLY caller --env keys a REVIEW dispatch accepts — deny by
# default. Round 8 (Claude N7): none. A reviewer needs nothing from its caller's environment:
# its git identity, sidecar id, focus scope and revision are all set by the dispatcher.
# Mirrors REVIEW_ENV_ALLOW in lib/verdict_ledger.py (pinned equal by t3580_round7/8 tests).
REVIEW_ENV_ALLOW=""

# T-3580 round 5: the VENDOR each worker kind runs comes from ONE mapping — `worker_kind` +
# `vendor` in policy/review-backends.yaml, read through lib/verdict_ledger.py kind-vendors. The
# ledger derives every review dispatch's vendor from the same mapping; this is only a printer.
_worker_vendor() {
    local k="${1:-claude}"
    python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" kind-vendors 2>/dev/null \
        | awk -v k="$k" '$1 == k { print $2; exit }'
}

cmd_worker_kinds() {
    local k
    if [ "${1:-}" = "--vendors" ]; then
        for k in $DISPATCH_WORKER_KINDS; do printf '%s %s\n' "$k" "$(_worker_vendor "$k")"; done
        return 0
    fi
    printf '%s\n' $DISPATCH_WORKER_KINDS
}

# T-3580 round 4: a review dispatch is finished only when the runtime has FINALISED it (signed its
# completion, or recorded that it could not), not when exit_code appears — run.sh writes
# exit_code first and signs after. Non-review dispatches carry no finalise_required marker.
# Round 5: `finalised` is VERIFIED, not trusted — the worker can write into its wdir too. It must
# read `signed:<sig>` with <sig> the sig in completion.json, or `unsigned:<reason>`; and run.sh
# (the worker's parent) must no longer be running, so a worker that writes it early is ignored.
_worker_done() {
    local w="${1%/}" f sig
    [ -f "$w/exit_code" ] || return 1
    [ -f "$w/finalise_required" ] || return 0
    [ -f "$w/finalised" ] || return 1
    f=$(head -1 "$w/finalised" 2>/dev/null)
    case "$f" in
        signed:?*)
            sig="${f#signed:}"
            python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("sig") == sys.argv[2] else 1)' \
                "$w/completion.json" "$sig" 2>/dev/null || return 1 ;;
        unsigned:?*) ;;
        *) return 1 ;;
    esac
    ! _runtime_alive "$w"
}

# True while a `run.sh` for this worker directory is still running.
_runtime_alive() {
    command -v pgrep >/dev/null 2>&1 || return 1
    pgrep -f -- "${1%/}/run.sh" >/dev/null 2>&1
}

cmd_dispatch() {
    ensure_termlink
    local task="" name="" prompt="" prompt_file="" project_dir="" timeout="$TERMLINK_WORKER_TIMEOUT" model="" task_type="" tools="" worker_kind="" permission_mode="" mcp_config="" strict_mcp="" allowed_tools="" review_revision="" review_run="" review_seat=""
    # T-1700: workflow `env:` plumb-through. Repeatable --env KEY=VAL pairs are
    # injected into the spawned worker's shell so `claude -p` honors per-workflow
    # overrides like ANTHROPIC_BASE_URL=http://localhost:4000 (litellm proxy)
    # without requiring caller to set them in parent env first.
    # T-1703: --tools plumbs the workflow `allowed_tools:` field through to
    # claude -p's --tools flag, restricting the catalogue presented to the model.
    local -a envs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --prompt) prompt="$2"; shift 2 ;;
            --prompt-file) prompt_file="$2"; shift 2 ;;
            --project) project_dir="$2"; shift 2 ;;
            --timeout) timeout="$2"; shift 2 ;;
            --model) model="$2"; shift 2 ;;
            --task-type) task_type="$2"; shift 2 ;;
            --review-revision)
                # T-3580 round 3: the commit a review worker is asked to review, captured by
                # the caller BEFORE dispatch. Registered with the dispatch; the verdict ledger
                # binds every verdict to it instead of HEAD at record time.
                review_revision="$2"; shift 2 ;;
            --review-run|--review-seat)
                # T-3580 round 6: the signed review run (and seat in it) this dispatch is
                # authorised under. Registered WITH the dispatch, before the worker launches;
                # the ledger reads the rung the run authorised, never one the worker types.
                [ "$1" = "--review-run" ] && review_run="$2" || review_seat="$2"; shift 2 ;;
            --env)
                # Validate KEY=VALUE shape early; KEY must match [A-Z_][A-Z0-9_]*
                if [[ ! "$2" =~ ^[A-Z_][A-Z0-9_]*= ]]; then
                    die "--env expects KEY=VALUE with KEY matching [A-Z_][A-Z0-9_]* (got: $2)"
                fi
                envs+=("$2"); shift 2 ;;
            --tools)
                # T-1703: comma-separated tool list passed to claude -p --tools.
                # No validation here — claude -p validates against its built-in set.
                tools="$2"; shift 2 ;;
            --worker-kind)
                # T-1706: select worker implementation. Default empty → claude -p.
                # `ollama-loop` → tools/ollama-tool-loop.py (curated litellm direct).
                worker_kind="$2"; shift 2 ;;
            --permission-mode)
                # T-2282: permission-mode passthrough to claude -p. Default empty
                # → claude -p uses its own default (interactive trust dialog).
                # Non-interactive workers needing MCP servers should pass
                # `acceptEdits` so the workspace trust dialog auto-resolves and
                # MCP server tools surface in the deferred catalogue. Without
                # this, .mcp.json-wired servers stay "status":"pending" and the
                # worker can't call mcp__*__* verbs (OBS-058 + OBS-059, 2026-06-09).
                # No validation here — claude -p validates the mode string.
                permission_mode="$2"; shift 2 ;;
            --mcp-config)
                # T-2284: --mcp-config passthrough to claude -p. Default empty
                # → claude -p uses parent's permissions.allow for MCP trust,
                # which leaves servers in "status":"pending" when the parent
                # has no per-server entry (OBS-060 + OBS-061, 2026-06-09).
                # Pass an explicit .mcp.json path so the worker brings up its
                # own MCP servers regardless of parent's trust state. Pairs
                # naturally with --strict-mcp-config to refuse anything outside
                # the supplied config.
                # No validation here — claude -p validates the file at startup.
                mcp_config="$2"; shift 2 ;;
            --strict-mcp-config)
                # T-2284: refuse MCP servers not in --mcp-config. Boolean flag,
                # no value. Composes with --mcp-config above; passing strict
                # without --mcp-config still surfaces as "--strict-mcp-config"
                # to claude -p (which will use its default config lookup).
                strict_mcp=1; shift ;;
            --allowed-tools)
                # T-2288 (substrate quintet, 5th onion layer): pre-approve tools
                # for non-interactive workers. Even with --mcp-config + --strict-mcp-config
                # + --permission-mode acceptEdits (substrate quartet), claude -p
                # still emits per-tool trust prompts on first invocation of each
                # MCP tool. Non-interactive workers (claude -p) cannot answer
                # the prompt and stall. Pass a comma-or-space-separated list
                # (e.g. "mcp__fw__work_on mcp__fw__task_update Read Write Bash")
                # to pre-grant trust for exactly those tools. Origin: arc010-hma-demo-004
                # (2026-06-09T13:43Z) — substrate-quartet active, worker invoked
                # mcp__fw__work_on twice, got "Claude requested permissions"
                # response both times, gave up at turn 8.
                # No validation here — claude -p validates the tool names.
                allowed_tools="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    case "$worker_kind" in
        ""|claude|ollama-loop|codex|opencode|antigravity) : ;;
        *) die "Unknown --worker-kind: $worker_kind (allowed: $DISPATCH_WORKER_KINDS)" ;;
    esac

    [ -z "$name" ] && die "Missing --name"
    if [ "$task_type" = "review" ]; then
        # T-3580 round 7: a review worker's program and model are not the caller's to choose.
        local _kv _k
        for _kv in "${envs[@]}"; do
            _k="${_kv%%=*}"
            case " $REVIEW_ENV_ALLOW " in
                *" $_k "*) : ;;
                *) die "--env $_k refused for a review dispatch: a review worker takes no environment from its caller. Its git identity, sidecar id, focus scope and reviewed revision are set by the dispatcher; a key that chooses its program, model or endpoint is never accepted. Drop --env for review dispatches (fw reviewer judge passes none)." ;;
            esac
        done
        # Round 8 (Claude N2): nor are its tools, permission mode or MCP servers — an MCP config
        # runs a program of the caller's choosing inside the reviewer. None is taken from the
        # caller; a kind that ever needs one gets it from committed config, not a flag.
        [ -n "$mcp_config" ] && die "--mcp-config refused for a review dispatch: a review worker runs no MCP server its caller chooses"
        [ -n "$strict_mcp" ] && die "--strict-mcp-config refused for a review dispatch: a review worker takes no MCP flags from its caller"
        [ -n "$allowed_tools" ] && die "--allowed-tools refused for a review dispatch: a review worker's tool trust is not its caller's to grant"
        [ -n "$tools" ] && die "--tools refused for a review dispatch: a review worker's tool catalogue is not its caller's to choose"
        [ -n "$permission_mode" ] && die "--permission-mode refused for a review dispatch: a review worker's permission mode is not its caller's to choose"
    fi
    # T-3581: a review dispatch id is registered once and must not be guessable (task+role).
    [ "$task_type" = "review" ] && name="${name}-$(od -An -N6 -tx1 /dev/urandom | tr -d ' \n')"
    [ -z "$task" ] && die "Missing --task — TermLink workers require a task reference for governance (T-652, T-630)"
    [ -z "$prompt" ] && [ -z "$prompt_file" ] && die "Missing --prompt or --prompt-file"

    if [ -n "$prompt_file" ]; then
        [ -f "$prompt_file" ] || die "Prompt file not found: $prompt_file"
        prompt=$(cat "$prompt_file")
    fi

    # T-1643/W1: auto-derive task_type from focus.yaml when omitted.
    if [ -z "$task_type" ]; then
        task_type=$(_derive_task_type)
    fi
    # T-3582: a harness kind is a review worker only — run.sh has no build/test path for it.
    case "$worker_kind" in
        codex|opencode|antigravity)
            [ "$task_type" = "review" ] || die "--worker-kind $worker_kind runs only as a review dispatch (--task-type review); got task type '${task_type:-none}'" ;;
    esac

    # T-1643/W3 + T-1664 + T-1669: resolve model.
    # Pre-T-1669: env-var lookup only.
    # T-1669: route_cache.best_model_for(task_type) consulted FIRST, env-var as fallback.
    # Returns "<model>|<fallback_used>|<source>".
    local _resolved resolution_source
    if [ "$task_type" = "review" ]; then
        # T-3580 round 8 (Claude N2): a review worker's model is the one the backend registry,
        # as committed at the reviewed revision, pins for its kind ('' = the worker's default).
        # Never the route cache, DISPATCH_MODEL_* config or a caller --model; the ledger signs
        # it into the registration and start checks run.sh was given exactly it.
        [ -n "$review_revision" ] || review_revision=$(git -C "${project_dir:-$(pwd)}" rev-parse -q --verify HEAD 2>/dev/null || true)
        local _pinned
        _pinned=$(PROJECT_ROOT="${project_dir:-$(pwd)}" python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" \
            kind-model --kind "${worker_kind:-claude}" --revision "$review_revision") \
            || die "review dispatch: no valid committed policy/review-backends.yaml to pin the worker model"
        if [ -n "$model" ] && [ "$model" != "$_pinned" ]; then
            die "--model refused for a review dispatch: the ${worker_kind:-claude} review worker runs '${_pinned:-its default model}' (policy/review-backends.yaml, committed); a caller cannot choose another"
        fi
        model="$_pinned"; fallback_used="false"; resolution_source="review-registry"
    else
        _resolved=$(_resolve_dispatch_model_and_fallback "$model" "$task_type")
        IFS='|' read -r model fallback_used resolution_source <<< "$_resolved"
    fi
    # JSON-safe: empty resolution → null (not the string "null"); non-empty model → quoted string.
    local model_used_json
    if [ -n "$model" ]; then
        model_used_json="\"$model\""
    else
        model_used_json="null"
    fi
    local fallback_used_json
    case "$fallback_used" in
        true|false) fallback_used_json="$fallback_used" ;;
        *)          fallback_used_json="null" ;;
    esac

    project_dir="${project_dir:-$(pwd)}"
    local wdir="$DISPATCH_DIR/$name"
    mkdir -p "$wdir"

    # T-3580 round 7: a review worker runs the binary resolved HERE, by absolute path (run.sh
    # never looks it up on PATH), and the caller's brief is kept verbatim in brief.md so the
    # ledger can check it is the one the review run registered for the seat.
    local worker_bin=""
    if [ "$task_type" = "review" ]; then
        if [ "${worker_kind:-claude}" = "ollama-loop" ]; then
            local _cand
            for _cand in "$FRAMEWORK_ROOT/tools/ollama-tool-loop.py" "$project_dir/tools/ollama-tool-loop.py"; do
                [ -x "$_cand" ] && { worker_bin="$_cand"; break; }
            done
        elif [ "${worker_kind:-claude}" != "claude" ]; then
            # T-3582: a harness kind's binary is the one the registry commits at the reviewed
            # revision — never PATH, never the caller. The ledger re-checks it at registration.
            worker_bin=$(PROJECT_ROOT="$project_dir" python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" \
                kind-binary --kind "$worker_kind" --revision "$review_revision") \
                || die "review dispatch: no valid committed policy/review-backends.yaml to pin the $worker_kind binary"
            [ -n "$worker_bin" ] || die "review dispatch: policy/review-backends.yaml (committed at ${review_revision:0:9}) pins no binary for worker kind $worker_kind"
        else
            worker_bin=$(command -v claude 2>/dev/null || true)
        fi
        [ -n "$worker_bin" ] && worker_bin=$(readlink -f "$worker_bin" 2>/dev/null || true)
        case "$worker_bin" in
            /*) [ -x "$worker_bin" ] || die "review dispatch: worker binary $worker_bin is not executable" ;;
            *) die "review dispatch: cannot resolve the ${worker_kind:-claude} worker binary to an absolute path" ;;
        esac
        printf '%s\n' "$worker_bin" > "$wdir/worker_bin"
        printf '%s\n' "$prompt" > "$wdir/brief.md"
    fi

    # T-3407 / arc-011 slice 5: every dispatched worker is addressable by its
    # --name and is told, once, how a peer consult reaches it. (Workers are NOT
    # launched --bare: run.sh passes no such flag, so CLAUDE.md, project hooks and
    # settings do load — round 8 corrected the old "--bare" claim here.) Kept
    # short: an empty inbox costs the worker one command.
    # T-3580 round 8 (Claude N1): NOT for a review dispatch. The stanza told every reviewer to
    # read and obey its inbox, which is a channel the task's producer can write to; a review
    # worker's prompt is exactly the ledger's fixed review preamble plus the brief, and the
    # ledger checks that equality at registration and at start.
    if [ "$task_type" != "review" ]; then
    local _consult_stanza="[PEER CONSULTS — arc-011 sidecar, T-3407]
You are addressable as agent id '$name'. Other agents may send you a consult
while you work. At each yield point (before a Write/Edit, and before you
finish), run:  fw sidecar inbox
If it prints a consult, answer it with:
  fw sidecar send --to <from> --conversation <conversation_id> --body '<answer>'
then continue your task. An empty inbox costs nothing; do not poll in a loop."
    prompt="$_consult_stanza

$prompt"
    fi

    # Save prompt, task tag, and metadata (from tl-dispatch.sh pattern)
    if [ "$task_type" = "review" ]; then
        python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" review-prompt --brief-file "$wdir/brief.md" \
            > "$wdir/prompt.md" || die "review dispatch: cannot build the review prompt"
    else
        echo "$prompt" > "$wdir/prompt.md"
    fi
    [ -n "$task" ] && echo "$task" > "$wdir/task"

    # T-1700: workflow env: plumb-through. Write env.sh sourced by run.sh.
    # Keys validated at parse time (KEY=VAL with KEY ∈ [A-Z_][A-Z0-9_]*).
    # Values are written verbatim with shell-quoted form so spaces/specials survive.
    : > "$wdir/env.sh"
    # T-2917: default worker git identity, written FIRST so any caller-supplied
    # --env GIT_AUTHOR_*/--env GIT_COMMITTER_* (e.g. forwarded by a resolver
    # dispatch — TermLinkWorker._build_dispatch_argv turns envelope["env"]
    # into --env pairs) overrides it: env.sh is sourced top-to-bottom, later
    # `export` wins. `$name` (required, unique per dispatch) stands in for a
    # dispatch_id here — this call path has no dispatches.jsonl row to join
    # against; the TermLink worker dir at /tmp/tl-dispatch/$name is the join
    # target instead. Mechanism is fixed "termlink-dispatch": this is the
    # direct-dispatch path (CLAUDE.md §Sub-Agent Dispatch Protocol), distinct
    # from a resolver-loop worker (which arrives with mechanism already set
    # via --env and overrides these lines).
    fw_worker_git_identity_env "termlink-dispatch" "$name" >> "$wdir/env.sh"
    # T-3407: the worker's sidecar identity IS its dispatch name, so
    # `fw sidecar send --to $name` lands in this worker's inbox with no
    # second naming scheme. Written before caller --env pairs so an explicit
    # --env FW_SIDECAR_AGENT_ID=... still wins (later export overrides).
    printf 'export FW_SIDECAR_AGENT_ID=%q\n' "$name" >> "$wdir/env.sh"
    # T-3580 round 3: a review worker is told which revision it reviews (the one registered).
    if [ "$task_type" = "review" ]; then
        [ -n "$review_revision" ] || review_revision=$(git -C "$project_dir" rev-parse -q --verify HEAD 2>/dev/null || true)
        printf 'export FW_REVIEW_REVISION=%q\n' "$review_revision" >> "$wdir/env.sh"
        # Round 8 (N1): marks a review worker, so the sidecar-inbox prompt hook stays silent in it.
        printf 'export FW_REVIEW_WORKER=%q\n' "1" >> "$wdir/env.sh"
    fi

    # T-3038 (OBS-291): give every dispatched worker its own focus file.
    #
    # Without this the worker's first `fw work-on` overwrites the SHARED
    # .context/working/focus.yaml — task and focus_session both — and the parent
    # session is then blocked by check-active-task.sh on every Write and every
    # Bash, read-only commands included. The parent gets locked out of its own
    # unrelated work by a worker it spawned, and re-asserting focus only holds
    # until the next worker calls work-on.
    #
    # Written BEFORE the caller's --env pairs so an explicit --env
    # FW_SESSION_SCOPED_FOCUS=0 can still opt a worker back onto the shared file
    # (same later-wins ordering the git identity block above relies on). The key
    # is $name, which dispatch already requires to be unique per worker.
    printf 'export FW_SESSION_SCOPED_FOCUS=%q\n' "1" >> "$wdir/env.sh"
    printf 'export FW_FOCUS_SESSION_KEY=%q\n' "$name" >> "$wdir/env.sh"

    # T-3422: seed that scoped file NOW, with the worker's own --task. Without
    # this the gate's read-side fallback (T-3038) hands the worker whatever task
    # the SHARED focus.yaml happens to hold until its first `fw work-on` —
    # observed as a different, unrelated, real task in four consecutive
    # SEQ-T3411 rounds (Δ8). Same resolver as the reader (lib/paths.sh), same
    # env the worker will run under, never overwrites an existing file.
    if ! declare -F fw_focus_seed >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        source "$FRAMEWORK_ROOT/lib/paths.sh" 2>/dev/null || true
    fi
    if declare -F fw_focus_seed >/dev/null 2>&1; then
        local _seeded
        _seeded=$(FW_SESSION_SCOPED_FOCUS=1 FW_FOCUS_SESSION_KEY="$name" \
                  fw_focus_seed "$project_dir" "$task") && \
            echo "  Focus seeded: $(basename "$_seeded") -> $task"
    fi

    local env_keys_json="[]"
    if [ "${#envs[@]}" -gt 0 ]; then
        local _key_list=""
        for kv in "${envs[@]}"; do
            local k="${kv%%=*}"
            local v="${kv#*=}"
            # printf %q produces a shell-safe single-token; export honors it.
            printf 'export %s=%q\n' "$k" "$v" >> "$wdir/env.sh"
            _key_list+="\"$k\","
        done
        env_keys_json="[${_key_list%,}]"
    fi

    # T-3580 round 8 (codex 1): a REVIEW worker's environment is data, not shell. The env.sh
    # built above (our own %q output) is turned into env.json — later assignments win, as they
    # did when sourced — and removed. The ledger signs env.json's hash at registration, refuses
    # a review wdir holding an env.sh, and run.sh loads the pairs through `verdict_ledger.py
    # review-env` and exports each one literally: no value is ever evaluated by a shell.
    if [ "$task_type" = "review" ]; then
        local -a _env_keys=()
        mapfile -t _env_keys < <(sed -n 's/^export \([A-Z_][A-Z0-9_]*\)=.*/\1/p' "$wdir/env.sh" | awk '!seen[$0]++')
        env -i PATH="$PATH" bash -c 'set -e; . "$1"; shift; for k in "$@"; do printf "%s=%s\0" "$k" "${!k}"; done' \
            _ "$wdir/env.sh" "${_env_keys[@]}" \
            | python3 -c 'import json,sys; d=dict(r.split("=",1) for r in sys.stdin.read().split("\0") if r); json.dump(d, open(sys.argv[1],"w"), sort_keys=True)' "$wdir/env.json" \
            || die "review dispatch: cannot write the worker environment as data"
        rm -f "$wdir/env.sh"
    fi

    # T-1706: worker_kind selection. Empty/claude → claude -p. ollama-loop →
    # tools/ollama-tool-loop.py (curated litellm /v1/messages direct).
    # File presence is the routing signal in run.sh (heredoc'd, no var interp).
    if [ -n "$worker_kind" ] && [ "$worker_kind" != "claude" ]; then
        printf '%s\n' "$worker_kind" > "$wdir/worker_kind.txt"
    fi
    local worker_kind_json="null"
    [ -n "$worker_kind" ] && worker_kind_json="\"$worker_kind\""

    # T-1703: workflow allowed_tools plumb-through. Write tools.txt read by run.sh
    # to construct --tools flag. Empty when no --tools passed (claude -p default).
    local tools_json="null"
    if [ -n "$tools" ]; then
        printf '%s\n' "$tools" > "$wdir/tools.txt"
        # Convert "Read,Bash,Grep" → ["Read","Bash","Grep"] for meta.json
        tools_json="[$(printf '%s' "$tools" | awk -F, '{for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i); printf "%s\"%s\"",(i>1?",":""),$i}}')]"
    fi

    # T-2282: --permission-mode plumb-through. Write permission_mode.txt read by
    # run.sh to construct --permission-mode flag. Empty when no flag passed
    # (claude -p uses its default; for non-interactive workers this leaves MCP
    # servers stuck "status":"pending" — see OBS-058/OBS-059).
    local permission_mode_json="null"
    if [ -n "$permission_mode" ]; then
        printf '%s\n' "$permission_mode" > "$wdir/permission_mode.txt"
        permission_mode_json="\"$permission_mode\""
    fi

    # T-2284: --mcp-config + --strict-mcp-config plumb-through. Write
    # mcp_config.txt (path string) and strict_mcp (sentinel file, presence ==
    # true) read by run.sh to construct MCP_CONFIG_FLAG + STRICT_MCP_FLAG.
    # Empty when no flag passed → claude -p uses parent's .mcp.json + parent's
    # permissions.allow, which leaves MCP servers pending for workers whose
    # parent has no per-server trust entry (OBS-060/OBS-061).
    local mcp_config_json="null"
    if [ -n "$mcp_config" ]; then
        printf '%s\n' "$mcp_config" > "$wdir/mcp_config.txt"
        # Escape quotes in path for JSON safety (paths rarely contain quotes,
        # but be defensive — same convention as model_used_json above).
        mcp_config_json="\"${mcp_config//\"/\\\"}\""
    fi
    local strict_mcp_json="false"
    if [ -n "$strict_mcp" ]; then
        : > "$wdir/strict_mcp"   # sentinel file — presence == enabled
        strict_mcp_json="true"
    fi
    # T-2288: --allowed-tools plumb-through. Write allowed_tools.txt read by
    # run.sh to construct --allowed-tools flag. Empty when no flag passed
    # (claude -p uses parent's permissions.allow for per-tool trust — which
    # for non-interactive workers means trust prompts that cannot be answered).
    local allowed_tools_json="null"
    if [ -n "$allowed_tools" ]; then
        printf '%s\n' "$allowed_tools" > "$wdir/allowed_tools.txt"
        allowed_tools_json="\"${allowed_tools//\"/\\\"}\""
    fi

    # T-1643/W4 + T-1664: meta.json includes task_type, model_used, fallback_used.
    # T-1700: env_keys lists the env var names injected (values not stored — possible secrets).
    # model_used / fallback_used now populated at dispatch time when resolution succeeds;
    # remain null when no model resolves (DISPATCH_MODEL_DEFAULT unset and no per-type pin).
    cat > "$wdir/meta.json" <<METAEOF
{
  "name": "$name",
  "project": "$project_dir",
  "timeout": $timeout,
  "task": "${task:-}",
  "task_type": "${task_type:-}",
  "model": "${model:-}",
  "model_used": $model_used_json,
  "fallback_used": $fallback_used_json,
  "resolution_source": "${resolution_source:-none}",
  "env_keys": $env_keys_json,
  "tools_restricted": $tools_json,
  "permission_mode": $permission_mode_json,
  "mcp_config": $mcp_config_json,
  "strict_mcp": $strict_mcp_json,
  "allowed_tools": $allowed_tools_json,
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running"
}
METAEOF

    # T-3581: a review dispatch is registered (HMAC-signed) so a verdict row can prove
    # which dispatch produced it. `$name` is the dispatch id. Only task-type review is
    # registered: the verdict ledger refuses any row whose dispatch is not in this registry.
    if [ "$task_type" = "review" ] && [ -n "$task" ] && [ -f "$FRAMEWORK_ROOT/lib/verdict_ledger.py" ]; then
        local _issuer_session
        _issuer_session=$(sed -n 's/^session_id:[[:space:]]*//p' "$project_dir/.context/working/session.yaml" 2>/dev/null | head -1)
        PROJECT_ROOT="$project_dir" python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" register-dispatch \
            --dispatch-id "$name" --task "$task" --task-type review \
            --revision "$review_revision" --wdir "$wdir" \
            --worker-kind "${worker_kind:-claude}" --ttl "$((timeout + 600))" \
            --run-id "$review_run" --seat "$review_seat" --worker-bin "$worker_bin" --model "$model" \
            --issuer-session "${_issuer_session:-}" --issuer-identity "${GIT_AUTHOR_NAME:-$(git -C "$project_dir" config user.name 2>/dev/null)}" \
            >/dev/null || echo "  WARNING: review dispatch not registered — its verdicts will not count" >&2
        : > "$wdir/finalise_required"
    fi

    # Worker script runs inside the spawned terminal
    # Adapted from tl-dispatch.sh — battle-tested with 3 parallel workers
    cat > "$wdir/run.sh" <<'RUNEOF'
#!/bin/bash
WORKER_NAME="$1"; PROJECT_DIR="$2"; WDIR="$3"; TIMEOUT="$4"; MODEL="$5"
TASK_TYPE="$6"; FW_BIN="$7"
cd "$PROJECT_DIR" || { echo "FATAL: cd $PROJECT_DIR failed" >> "$WDIR/stderr.log"; exit 1; }

# T-3580 round 6: the completion secret is ISSUED to this runtime by its authenticated start
# (below), never written to disk by registration. Deliberately NOT exported; it reaches
# `complete` only on stdin, after the worker has exited.
COMPLETION_SECRET=""

# T-3580 round 7: a review worker is launched by the ABSOLUTE path the dispatcher resolved and
# registered (worker_bin), never looked up on PATH; `start` refuses if it changed.
WORKER_BIN="claude"
if [ "$TASK_TYPE" = "review" ]; then
    WORKER_BIN=$(cat "$WDIR/worker_bin" 2>/dev/null)
    case "$WORKER_BIN" in /*) : ;; *) WORKER_BIN="" ;; esac
fi

# T-792: Export PROJECT_ROOT so hooks skip git resolution and use the correct project
export PROJECT_ROOT="$PROJECT_DIR"
# T-2285 (OBS-062): discriminate framework-self vs consumer before redirecting
# FRAMEWORK_ROOT to .agentic-framework/. The .agentic-framework/ directory
# exists in BOTH cases — consumers have it as the vendored framework source,
# and the framework REPO itself has it as a self-vendored mirror (verified
# by `fw vendor self`). Redirecting FRAMEWORK_ROOT to the mirror in the
# framework repo breaks subsystems that read source-only assets like
# policy/capability-overlay/tool-set.yaml — the mirror doesn't carry policy/.
# Use FRAMEWORK.md at PROJECT_DIR's root as the discriminator: only the
# framework REPO has it; consumers don't.
if [ -f "$PROJECT_DIR/FRAMEWORK.md" ]; then
    # Framework repo: PROJECT_ROOT == FRAMEWORK_ROOT (source is at root).
    export FRAMEWORK_ROOT="$PROJECT_DIR"
elif [ -d "$PROJECT_DIR/.agentic-framework" ]; then
    # Consumer with vendored framework: redirect to .agentic-framework/.
    export FRAMEWORK_ROOT="$PROJECT_DIR/.agentic-framework"
else
    # Bare project with no framework wiring: FRAMEWORK_ROOT==PROJECT_ROOT.
    export FRAMEWORK_ROOT="$PROJECT_DIR"
fi

# T-3580 round 5: evidence that THIS runtime started for the dispatch — a signed start record,
# written before the worker runs and within the registration's start window. Round 6: the start
# also ISSUES the completion secret (printed once, to this command substitution only), and the
# ledger authenticates the caller itself: its parent must be this very run.sh, byte-identical to
# the runtime termlink.sh writes. A dispatch that never ran has no start and so no secret.
if [ "$TASK_TYPE" = "review" ] && [ -f "$FRAMEWORK_ROOT/lib/verdict_ledger.py" ]; then
    COMPLETION_SECRET=$(env -u FW_SIDECAR_AGENT_ID PROJECT_ROOT="$PROJECT_DIR" \
        python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" start \
        --dispatch-id "$WORKER_NAME" --wdir "$WDIR" 2>> "$WDIR/stderr.log") \
        || COMPLETION_SECRET=""
fi
# T-3582 (T-3580 R9-1): a review whose start was refused (or never attempted) launches NO worker:
# it could only ever produce verdicts that never count. The reason stays in stderr.log, which
# every write below APPENDS to.
START_REFUSED=""
if [ "$TASK_TYPE" = "review" ] && [ -z "$COMPLETION_SECRET" ]; then
    START_REFUSED=1
    WORKER_BIN=""
    echo "REFUSED: review start not recorded — the worker is NOT launched (reason: $WDIR/stderr.log)"
fi

# T-576: Unset CLAUDECODE to allow nested claude sessions from within Claude Code
unset CLAUDECODE 2>/dev/null || true

# T-1700: Source per-workflow env overrides written by cmd_dispatch (e.g.
# ANTHROPIC_BASE_URL=http://localhost:4000 for litellm/ollama dispatch).
# File contains `export KEY=value` lines, one per --env arg, escaped with %q.
# Empty when no --env passed. Sourced AFTER PROJECT_ROOT/FRAMEWORK_ROOT so those
# can be overridden too if a workflow needs it.
# T-3580 round 8 (codex 1): NOT for a review worker, whose environment is data (env.json),
# verified against its signed registration by `review-env` and exported pair by pair with no
# shell evaluation. A refusal (env changed after registration or start) launches no worker.
if [ "$TASK_TYPE" = "review" ]; then
    _ENV_OK=""
    while IFS= read -r -d '' _KV; do
        if [ "$_KV" = "__FW_ENV_END__" ]; then _ENV_OK=1; break; fi
        case "$_KV" in [A-Z_]*=*) export "$_KV" ;; *) _ENV_OK=""; break ;; esac
    done < <(env -u FW_SIDECAR_AGENT_ID PROJECT_ROOT="$PROJECT_DIR" python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" \
                review-env --dispatch-id "$WORKER_NAME" --wdir "$WDIR" 2>> "$WDIR/stderr.log")
    if [ -z "$_ENV_OK" ]; then
        echo "WARNING: review worker environment refused — the worker is not launched"
        WORKER_BIN=""
    fi
else
[ -f "$WDIR/env.sh" ] && . "$WDIR/env.sh"
fi

# T-1065: Build model flag if specified
MODEL_FLAG=""
if [ -n "$MODEL" ]; then
    MODEL_FLAG="--model $MODEL"
fi

# T-1703: Build --tools flag if tools.txt was written by cmd_dispatch.
# Empty file / missing file → claude -p uses default catalogue (~100 tools).
# Present → restricts to the comma-separated list (e.g. "Read,Bash,Grep").
TOOLS_FLAG=""
if [ -f "$WDIR/tools.txt" ] && [ -s "$WDIR/tools.txt" ]; then
    TOOLS_FLAG="--tools $(cat "$WDIR/tools.txt")"
fi

# T-2282: Build --permission-mode flag if permission_mode.txt was written by
# cmd_dispatch. Empty/missing → claude -p uses its default (workspace trust
# dialog, which can't fire non-interactively, leaving MCP servers in "pending"
# state). Pass `acceptEdits` for non-interactive MCP-using workers (OBS-058).
PERMISSION_MODE_FLAG=""
if [ -f "$WDIR/permission_mode.txt" ] && [ -s "$WDIR/permission_mode.txt" ]; then
    PERMISSION_MODE_FLAG="--permission-mode $(cat "$WDIR/permission_mode.txt")"
fi

# T-2284: Build --mcp-config flag if mcp_config.txt was written by cmd_dispatch.
# Empty/missing → claude -p inherits parent's .mcp.json + permissions.allow,
# leaving MCP servers pending when the parent has no per-server trust entry
# (OBS-060/OBS-061). Path is read verbatim — caller is responsible for
# correctness (claude -p validates at startup).
MCP_CONFIG_FLAG=""
if [ -f "$WDIR/mcp_config.txt" ] && [ -s "$WDIR/mcp_config.txt" ]; then
    MCP_CONFIG_FLAG="--mcp-config $(cat "$WDIR/mcp_config.txt")"
fi

# T-2284: Build --strict-mcp-config flag if strict_mcp sentinel was written.
# Composes with MCP_CONFIG_FLAG. Boolean — file presence == enabled.
STRICT_MCP_FLAG=""
if [ -f "$WDIR/strict_mcp" ]; then
    STRICT_MCP_FLAG="--strict-mcp-config"
fi

# T-2288: Build --allowed-tools flag if allowed_tools.txt was written by
# cmd_dispatch. Empty/missing → claude -p uses parent's permissions.allow for
# per-tool trust. For non-interactive workers this leaves trust prompts that
# cannot be answered (arc010-hma-demo-004 origin).
ALLOWED_TOOLS_FLAG=""
if [ -f "$WDIR/allowed_tools.txt" ] && [ -s "$WDIR/allowed_tools.txt" ]; then
    ALLOWED_TOOLS_FLAG="--allowed-tools $(cat "$WDIR/allowed_tools.txt")"
fi

# T-3580 round 8 (Claude N2): a review worker takes none of the flags above from its worker
# directory (start already refused if one was there; this closes the window after start), and
# loads only user and project settings: never the untracked .claude/settings.local.json, whose
# env block (ANTHROPIC_BASE_URL, ANTHROPIC_MODEL) and hooks would choose its endpoint, model
# and extra programs. `--setting-sources` is claude's documented flag (claude --help).
# Round 9 (Claude R8-1): the USER source only — the working tree's .claude/settings.json (env,
# hooks, model) is not loaded either — plus `--settings` naming the ledger's pinned copy of
# policy/review-worker-settings.json (cross-session inbound refused; signed at registration,
# re-checked at start and complete), and `--strict-mcp-config` with no --mcp-config: no MCP
# server from .mcp.json or anywhere else. `start` refuses when CLAUDE.md, .claude/ or .mcp.json
# differ from the reviewed revision.
SETTING_SOURCES_FLAG=""
if [ "$TASK_TYPE" = "review" ]; then
    TOOLS_FLAG=""; PERMISSION_MODE_FLAG=""; MCP_CONFIG_FLAG=""; ALLOWED_TOOLS_FLAG=""
    STRICT_MCP_FLAG="--strict-mcp-config"
    SETTING_SOURCES_FLAG="--setting-sources user --settings $WDIR/settings.json"
fi

# T-1706: worker_kind dispatch routing. If worker_kind.txt requests ollama-loop,
# run the thin tool-loop worker (curated litellm direct, ~150 LOC python). The
# python worker writes result.jsonl + result.md + exit_code itself, so we skip
# the claude -p branch entirely.
WORKER_KIND=""
[ -f "$WDIR/worker_kind.txt" ] && WORKER_KIND=$(cat "$WDIR/worker_kind.txt")
# T-3582: harness kinds (lib/verdict_ledger.py HARNESS_KINDS; a test pins the two equal).
HARNESS=""
case "$WORKER_KIND" in codex|opencode|antigravity) HARNESS=1 ;; esac

if [ "$WORKER_KIND" = "ollama-loop" ]; then
    # Resolve project's ollama-tool-loop.py — prefer FRAMEWORK_ROOT if vendored,
    # else PROJECT_ROOT/tools (framework repo case).
    LOOP_BIN=""
    for cand in "$FRAMEWORK_ROOT/tools/ollama-tool-loop.py" "$PROJECT_DIR/tools/ollama-tool-loop.py"; do
        if [ -x "$cand" ]; then LOOP_BIN="$cand"; break; fi
    done
    [ "$TASK_TYPE" = "review" ] && LOOP_BIN="$WORKER_BIN"
    if [ -z "$LOOP_BIN" ]; then
        echo "FATAL: ollama-tool-loop.py not found or not launched" >> "$WDIR/stderr.log"
        EXIT_CODE=1
        echo 1 > "$WDIR/exit_code"
    else
        # Pass model alias as OLLAMA_LOOP_MODEL when --model was supplied.
        [ -n "$MODEL" ] && export OLLAMA_LOOP_MODEL="$MODEL"
        ( python3 "$LOOP_BIN" --wdir "$WDIR" >"$WDIR/stdout.log" 2>>"$WDIR/stderr.log" ) &
        LOOP_PID=$!
        (sleep "$TIMEOUT" && kill "$LOOP_PID" 2>/dev/null && echo "TIMEOUT" >> "$WDIR/stderr.log") &
        WATCHDOG_PID=$!
        wait "$LOOP_PID" 2>/dev/null
        EXIT_CODE=$?
        kill "$WATCHDOG_PID" 2>/dev/null || true
        # Worker already wrote exit_code; respect it. If absent, fall back.
        [ ! -f "$WDIR/exit_code" ] && echo "$EXIT_CODE" > "$WDIR/exit_code"
    fi
elif [ -n "$HARNESS" ]; then
    # T-3582: a harness reviewer (codex / opencode / antigravity) runs READ-ONLY in a `git archive`
    # export of the reviewed revision, never in the shared working tree: what it loads (AGENTS.md,
    # project config) IS the reviewed revision, a concurrent session's dirty file cannot reach it,
    # and the antigravity user (who cannot read the root-owned project) can read it. Binary and
    # model are the registered ones; no caller flag or env reaches the command line. It PRINTS
    # its verdicts; result.md is normalised to the final text, and the runtime records them below.
    EXIT_CODE=1
    TREE="$WDIR/tree"
    if [ "$TASK_TYPE" != "review" ] || [ -z "$WORKER_BIN" ]; then
        echo "FATAL: $WORKER_KIND worker not launched (a harness kind runs only as a started review dispatch)" >> "$WDIR/stderr.log"
    elif ! { mkdir -p "$TREE" && git -C "$PROJECT_DIR" archive --format=tar "${FW_REVIEW_REVISION:-HEAD}" -- . ':(exclude).context' | tar -x -C "$TREE"; }; then
        echo "FATAL: cannot export revision ${FW_REVIEW_REVISION:-HEAD} for the $WORKER_KIND worker" >> "$WDIR/stderr.log"
    else
        chmod -R a+rX "$WDIR" 2>/dev/null
        PROMPT_TEXT="$(cat "$WDIR/prompt.md")"
        case "$WORKER_KIND" in
            codex)
                # -s read-only: no writes (the CLI itself writes -o); --ignore-user-config and
                # --ignore-rules: no ~/.codex/config.toml or execpolicy rules (auth still loads);
                # project_doc_max_bytes=0: AGENTS.md is not injected; --ephemeral: no session files.
                ( cd "$TREE" && exec "$WORKER_BIN" exec -s read-only --skip-git-repo-check --ignore-user-config --ignore-rules --ephemeral --color never -c project_doc_max_bytes=0 ${MODEL:+-m "$MODEL"} --json -o "$WDIR/result.md" "$PROMPT_TEXT" < /dev/null > "$WDIR/result.jsonl" 2>> "$WDIR/stderr.log" ) &
                ;;
            opencode)
                # --agent plan: opencode's built-in no-edit agent; --pure: no external plugins;
                # --format json: raw events (no ANSI), normalised to result.md below.
                ( cd "$TREE" && exec "$WORKER_BIN" run ${MODEL:+-m "$MODEL"} --agent plan --pure --format json "$PROMPT_TEXT" < /dev/null > "$WDIR/result.jsonl" 2>> "$WDIR/stderr.log" ) &
                ;;
            antigravity)
                # The operator-approved form (2026-09-30), with the registered absolute binary:
                # sudo's secure_path does not reach ~/.local/bin. sudo drops this environment.
                ( cd "$TREE" && exec /usr/bin/sudo -n -u dimitri-mint-dev -H "$WORKER_BIN" -p "$PROMPT_TEXT" --mode plan --sandbox < /dev/null > "$WDIR/result.md" 2>> "$WDIR/stderr.log" ) &
                ;;
        esac
        HARNESS_PID=$!
        (sleep "$TIMEOUT" && kill "$HARNESS_PID" 2>/dev/null && echo "TIMEOUT" >> "$WDIR/stderr.log") &
        WATCHDOG_PID=$!
        wait "$HARNESS_PID" 2>/dev/null
        EXIT_CODE=$?
        kill "$WATCHDOG_PID" 2>/dev/null || true
        # Normalise every harness to one result.md: the worker's final text, no ANSI.
        python3 - "$WDIR" "$WORKER_KIND" <<'PYEOF' 2>> "$WDIR/stderr.log" || true
import json, re, sys
from pathlib import Path
w, kind = Path(sys.argv[1]), sys.argv[2]
ansi = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07]*\x07")
if kind == "opencode":
    parts = []
    for line in (w / "result.jsonl").read_text(errors="replace").splitlines() if (w / "result.jsonl").is_file() else []:
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if isinstance(ev, dict) and ev.get("type") == "text":
            parts.append(str((ev.get("part") or {}).get("text") or ""))
    (w / "result.md").write_text("\n".join(p for p in parts if p).strip() + "\n")
elif (w / "result.md").is_file():
    (w / "result.md").write_text(ansi.sub("", (w / "result.md").read_text(errors="replace")))
PYEOF
        [ -f "$WDIR/result.md" ] || : > "$WDIR/result.md"
    fi
    case "$TREE" in "$WDIR"/tree) rm -rf -- "$TREE" ;; esac
    echo "$EXIT_CODE" > "$WDIR/exit_code"
else
    # Background process + kill watchdog (macOS has no `timeout` command)
    # T-1663: stream-json preserves forensic trail when watchdog kills the worker — text format
    # buffers everything until completion, leaving an empty result.md on timeout (T-1643 found
    # this twice consecutively on U-005 dispatches). result.jsonl is the live trail; result.md
    # carries the final assistant text extracted on clean exit (backward-compat with `fw termlink result`).
    if [ -z "$WORKER_BIN" ]; then
        echo "FATAL: review worker binary not resolved to an absolute path" >> "$WDIR/stderr.log"
        CLAUDE_PID=""
    else
        "$WORKER_BIN" -p "$(cat "$WDIR/prompt.md")" $MODEL_FLAG $SETTING_SOURCES_FLAG $TOOLS_FLAG $PERMISSION_MODE_FLAG $MCP_CONFIG_FLAG $STRICT_MCP_FLAG $ALLOWED_TOOLS_FLAG --output-format stream-json --verbose > "$WDIR/result.jsonl" 2>>"$WDIR/stderr.log" &
        CLAUDE_PID=$!
    fi
    if [ -z "$CLAUDE_PID" ]; then
        EXIT_CODE=1
    else
    (sleep "$TIMEOUT" && kill "$CLAUDE_PID" 2>/dev/null && echo "TIMEOUT" >> "$WDIR/stderr.log") &
    WATCHDOG_PID=$!
    wait "$CLAUDE_PID" 2>/dev/null
    EXIT_CODE=$?
    kill "$WATCHDOG_PID" 2>/dev/null || true
    fi

    # Extract final assistant text into result.md for backward-compat. On timeout the result event
    # never arrived, result.md stays empty — operators read result.jsonl directly for forensic trail.
    if [ -s "$WDIR/result.jsonl" ] && command -v jq >/dev/null 2>&1; then
        jq -r 'select(.type=="result") | .result // empty' "$WDIR/result.jsonl" > "$WDIR/result.md" 2>/dev/null || : > "$WDIR/result.md"
    else
        : > "$WDIR/result.md"
    fi

    echo "$EXIT_CODE" > "$WDIR/exit_code"
fi
FINISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "$FINISHED_AT" > "$WDIR/finished_at"

# T-3580 round 3: a review worker's verdicts count only with a completion the RUNTIME signs
# here, after the worker has exited: its session, exit state, result-stream hash and the exact
# rows it left. The worker cannot write it (`record` never does, and `complete` refuses inside
# the worker's environment, so FW_SIDECAR_AGENT_ID is stripped for this one call).
# Round 4: the secret goes in on stdin, and `finalised` is written after signing succeeds or
# fails, so a review wait never returns between exit_code and the completion.
# T-3582: a harness worker cannot record its own verdict; the runtime records what it printed, on
# its behalf and under its identity, BEFORE signing — so the completion lists those rows.
if [ "$TASK_TYPE" = "review" ] && [ -n "$HARNESS" ] && [ -n "$COMPLETION_SECRET" ] && \
    [ -f "$FRAMEWORK_ROOT/lib/verdict_ledger.py" ]; then
    printf '%s' "$COMPLETION_SECRET" | env -u FW_SIDECAR_AGENT_ID PROJECT_ROOT="$PROJECT_DIR" \
        python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" record-for-worker \
        --dispatch-id "$WORKER_NAME" --wdir "$WDIR" --secret-stdin > "$WDIR/recorded.json" 2>> "$WDIR/stderr.log" \
        || echo "WARNING: the $WORKER_KIND worker's verdicts were not all recorded (see $WDIR/recorded.json)"
fi
if [ "$TASK_TYPE" = "review" ]; then
    FINAL="unsigned:completion-refused"
    if [ -f "$FRAMEWORK_ROOT/lib/verdict_ledger.py" ] && \
        printf '%s' "$COMPLETION_SECRET" | env -u FW_SIDECAR_AGENT_ID PROJECT_ROOT="$PROJECT_DIR" \
        python3 "$FRAMEWORK_ROOT/lib/verdict_ledger.py" complete \
        --dispatch-id "$WORKER_NAME" --session "$WORKER_NAME" --wdir "$WDIR" \
        --worker-kind "${WORKER_KIND:-claude}" --secret-stdin \
        --exit-code "$(cat "$WDIR/exit_code")" > "$WDIR/completion.json" 2>> "$WDIR/stderr.log"; then
        # Round 5: `finalised` carries the completion's own sig; `wait` checks it against
        # completion.json, so a value the worker wrote early does not match.
        FINAL="signed:$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["sig"])' "$WDIR/completion.json" 2>/dev/null)"
        [ "$FINAL" = "signed:" ] && FINAL="unsigned:no-sig"
    else
        echo "WARNING: review completion not signed — this worker's verdicts will not count"
    fi
    COMPLETION_SECRET=""
    echo "$FINAL" > "$WDIR/finalised"
fi

# Round 4: /tmp/tl-dispatch is not durable (a wdir vanished before its result was collected).
# Keep a copy of the worker's result in the project, where `fw termlink result` also looks.
if [ -s "$WDIR/result.md" ]; then
    mkdir -p "$PROJECT_DIR/.context/dispatch-results" 2>/dev/null \
        && cp "$WDIR/result.md" "$PROJECT_DIR/.context/dispatch-results/$WORKER_NAME.md" 2>/dev/null || true
fi

# T-1681: rewrite meta.json post-exit so `fw termlink dispatch_status` reflects
# reality. Pre-patch behaviour: meta.json was written at spawn with
# status:running and never updated, so dispatch_status reported running forever
# even though exit_code/finished_at/record-outcome had all fired. Best-effort —
# skipped silently when jq is unavailable (same pattern as result.md extraction).
if command -v jq >/dev/null 2>&1 && [ -f "$WDIR/meta.json" ]; then
    NEW_STATUS=$([ "$EXIT_CODE" -eq 0 ] && echo done || echo failed)
    jq --arg s "$NEW_STATUS" --argjson ec "$EXIT_CODE" --arg fa "$FINISHED_AT" \
       '.status = $s | .exit_code = $ec | .ended = $fa' \
       "$WDIR/meta.json" > "$WDIR/meta.json.tmp" 2>/dev/null \
        && mv "$WDIR/meta.json.tmp" "$WDIR/meta.json" \
        || rm -f "$WDIR/meta.json.tmp"
fi

# --- T-3440 close-state check (start) ---
# A `claude -p` worker has no next turn. If it ended its turn waiting on a
# background job, the close never ran and exit 0 means nothing: the work may be
# done but the task is still open and nobody is left alive to close it (three
# instances on 2026-09-22 — T-3211, T-3431/T-3435, T-3433). Decide here, while
# the task id and the exit code are both in hand.
#   incomplete — exit 0, task file still in .tasks/active/ as started-work
#   closed     — task in .tasks/completed/, or work-completed in active/
#                (partial-complete, waiting on a Human AC — the worker did its part)
#   n/a        — no task dispatched, no task file found, non-zero exit, or any
#                other status (nothing to assert)
CLOSE_TASK=""
[ -f "$WDIR/task" ] && CLOSE_TASK=$(cat "$WDIR/task" 2>/dev/null)
CLOSE_STATE="n/a"
if [ -n "$CLOSE_TASK" ] && [ "${EXIT_CODE:-1}" = "0" ]; then
    _cs_found=""
    for _cs_cand in "$PROJECT_DIR/.tasks/completed/$CLOSE_TASK"-*.md \
                    "$PROJECT_DIR/.tasks/completed/$CLOSE_TASK.md"; do
        [ -f "$_cs_cand" ] || continue
        CLOSE_STATE="closed"; _cs_found="$_cs_cand"; break
    done
    if [ -z "$_cs_found" ]; then
        for _cs_cand in "$PROJECT_DIR/.tasks/active/$CLOSE_TASK"-*.md \
                        "$PROJECT_DIR/.tasks/active/$CLOSE_TASK.md"; do
            [ -f "$_cs_cand" ] || continue
            _cs_status=$(grep -m1 '^status:' "$_cs_cand" 2>/dev/null \
                | sed 's/^status:[[:space:]]*//; s/[[:space:]]*$//')
            case "$_cs_status" in
                started-work)   CLOSE_STATE="incomplete" ;;
                work-completed) CLOSE_STATE="closed" ;;
                *)              CLOSE_STATE="n/a" ;;
            esac
            break
        done
    fi
fi
echo "$CLOSE_STATE" > "$WDIR/close_state"
if [ "$CLOSE_STATE" = "incomplete" ]; then
    echo "WARNING: worker exited 0 but $CLOSE_TASK is still started-work — close not run"
fi
# Same best-effort jq pattern as the meta.json rewrite above.
if command -v jq >/dev/null 2>&1 && [ -f "$WDIR/meta.json" ]; then
    jq --arg cs "$CLOSE_STATE" --arg ct "$CLOSE_TASK" \
       '.close_state = $cs | .close_state_task = $ct' \
       "$WDIR/meta.json" > "$WDIR/meta.json.tmp" 2>/dev/null \
        && mv "$WDIR/meta.json.tmp" "$WDIR/meta.json" \
        || rm -f "$WDIR/meta.json.tmp"
fi
# --- T-3440 close-state check (end) ---

# T-1669 Step 2: record outcome into route_cache so future dispatches can
# learn from it. Best-effort — missing model / task_type / fw skips silently.
# T-3440: --close-state rides along; an incomplete close is not a success.
if [ -n "$MODEL" ] && [ -n "$TASK_TYPE" ] && [ -n "$FW_BIN" ] && [ -x "$FW_BIN" ]; then
    "$FW_BIN" termlink record-outcome \
        --model "$MODEL" --task-type "$TASK_TYPE" --exit-code "$EXIT_CODE" \
        --close-state "$CLOSE_STATE" --task "$CLOSE_TASK" \
        >/dev/null 2>&1 || true
fi

termlink event emit "$WORKER_NAME" worker.done \
    -p "{\"exit_code\":$EXIT_CODE,\"result\":\"$WDIR/result.md\"}" 2>/dev/null || true

echo ""
echo "=== Worker $WORKER_NAME finished (exit: $EXIT_CODE) ==="
echo "Result: $WDIR/result.md"
# T-3582 (R9-1): a refused start is a visible, non-zero end — no worker ran.
if [ -n "$START_REFUSED" ]; then
    echo "REFUSED: review start refused — no worker was launched"
    exit 3
fi
exit 0
RUNEOF
    chmod +x "$wdir/run.sh"

    # Spawn terminal session — propagate task_type so the long-lived session
    # carries the task-type:X tag (T-1643/W2).
    cmd_spawn ${task:+--task "$task"} ${task_type:+--task-type "$task_type"} --name "$name"

    # Inject worker script via pty inject (fire-and-forget, NOT interact — claude takes minutes)
    sleep 1
    # T-1669 Step 2: pass task_type + fw binary path so the worker can
    # record outcome into route_cache after it exits.
    local fw_bin="${FRAMEWORK_ROOT:-$(dirname "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")")}/bin/fw"
    [ -x "$fw_bin" ] || fw_bin=""
    termlink pty inject "$name" "bash $wdir/run.sh '$name' '$project_dir' '$wdir' '$timeout' '$model' '$task_type' '$fw_bin'" --enter >/dev/null 2>&1


    echo "Worker spawned: $name (wdir: $wdir)"
}

cmd_wait() {
    ensure_termlink
    local name="" wait_all=false timeout="$TERMLINK_WORKER_TIMEOUT"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) name="$2"; shift 2 ;;
            --all) wait_all=true; shift ;;
            --timeout) timeout="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    if [ "$wait_all" = true ]; then
        # Wait for all workers (from tl-dispatch.sh)
        [ -d "$DISPATCH_DIR" ] || die "No workers dispatched"
        local deadline=$(($(date +%s) + timeout))
        while [ "$(date +%s)" -lt "$deadline" ]; do
            local all_done=true
            for wdir in "$DISPATCH_DIR"/*/; do
                [ -d "$wdir" ] || continue
                _worker_done "$wdir" || { all_done=false; break; }
            done
            [ "$all_done" = true ] && { echo "All workers complete."; return 0; }
            sleep 2
        done
        echo "Timeout waiting for workers."; return 1
    else
        [ -z "$name" ] && die "Missing --name (or use --all)"
        local wdir="$DISPATCH_DIR/$name"
        [ -d "$wdir" ] || die "No worker named '$name'"

        # Event-based wait first, file confirmation fallback
        # (from tl-dispatch.sh — termlink event wait is faster than polling)
        termlink list 2>/dev/null | grep -q "$name" && \
            termlink event wait "$name" --topic worker.done --timeout "$timeout" >/dev/null 2>&1 || true

        local deadline=$(($(date +%s) + timeout))
        while ! _worker_done "$wdir" && [ "$(date +%s)" -lt "$deadline" ]; do sleep 1; done

        if _worker_done "$wdir"; then
            local ec
            ec=$(cat "$wdir/exit_code")
            echo "Worker $name finished (exit: $ec)"
            return "$ec"
        else
            echo "Timeout waiting for worker $name"; return 1
        fi
    fi
}

cmd_result() {
    local name="${1:-}"
    [ -z "$name" ] && die "Usage: fw termlink result <worker-name>"

    local wdir="$DISPATCH_DIR/$name"
    if [ ! -d "$wdir" ]; then
        # T-3580 round 4: run.sh keeps a durable copy in the project; use it once /tmp is gone.
        local kept="${PROJECT_ROOT:-$(pwd)}/.context/dispatch-results/$name.md"
        [ -f "$kept" ] && { cat "$kept"; return 0; }
        die "No dispatch directory for worker '$name'"
    fi

    # T-3440: lead with the close verdict. A worker that ended its turn waiting
    # on a background job exits 0 with a perfectly readable result and an open
    # task — the parent needs to see that without opening the worker directory.
    if [ -f "$wdir/close_state" ]; then
        local cs ct=""
        cs=$(cat "$wdir/close_state" 2>/dev/null)
        [ -f "$wdir/task" ] && ct=$(cat "$wdir/task" 2>/dev/null)
        if [ "$cs" = "incomplete" ]; then
            echo -e "${YELLOW}WARN${NC}  close_state: incomplete — ${ct:-the dispatched task} is still started-work (worker exited 0, close not run)"
        elif [ "$cs" != "n/a" ]; then
            echo "close_state: $cs${ct:+ ($ct)}"
        fi
    fi

    # T-3519: token usage, from the result line's modelUsage. Operator instruction
    # 2026-09-27 — report cost in tokens, not dollars, and embed it rather than
    # recomputing it by hand per dispatch. Prints UNAVAILABLE (never 0) while a
    # worker is still running: see lib/dispatch_tokens.py for why a per-turn sum of
    # `usage` is the wrong measurement and what it gets wrong.
    if [ -f "$FRAMEWORK_ROOT/lib/dispatch_tokens.py" ]; then
        python3 "$FRAMEWORK_ROOT/lib/dispatch_tokens.py" "$name" 2>/dev/null || true
    fi

    if [ -f "$wdir/result.md" ]; then
        cat "$wdir/result.md"
    else
        echo -e "${YELLOW}WARN${NC}  No result file yet for worker '$name'"
        if [ -f "$wdir/stderr.log" ] && [ -s "$wdir/stderr.log" ]; then
            echo "stderr:"
            cat "$wdir/stderr.log"
        fi
        return 1
    fi
}

cmd_update() {
    local repo_dir="${TERMLINK_REPO:-/opt/termlink}"
    local quiet=false
    [ "${1:-}" = "--quiet" ] && quiet=true

    # T-3129: `-e` — a TermLink checkout that happens to be a linked worktree
    # has a `.git` file, and the `git fetch` below works fine from one.
    if [ ! -e "$repo_dir/.git" ]; then
        $quiet && exit 1
        die "TermLink repo not found at $repo_dir\n  Set TERMLINK_REPO or clone: git clone https://onedev.docker.ring20.geelenandcompany.com/termlink $repo_dir"
    fi

    # Check for updates
    cd "$repo_dir"
    git fetch --quiet 2>/dev/null || die "Failed to fetch from remote"
    local local_head remote_head
    local_head=$(git rev-parse HEAD)
    remote_head=$(git rev-parse '@{u}' 2>/dev/null || echo "unknown")

    if [ "$local_head" = "$remote_head" ]; then
        $quiet || echo -e "${GREEN}OK${NC}  TermLink is up to date ($(git log --oneline -1))"
        return 0
    fi

    if $quiet; then
        echo -e "${YELLOW}UPDATE${NC}  TermLink update available"
        echo "  Local:  $(git log --oneline -1)"
        echo "  Remote: $(git log --oneline -1 '@{u}')"
        echo "  Run: fw termlink update"
        return 0
    fi

    echo -e "${YELLOW}Updating TermLink...${NC}"
    echo "  Before: $(git log --oneline -1)"
    git pull --quiet 2>/dev/null || die "git pull failed"
    echo "  After:  $(git log --oneline -1)"

    # Rebuild
    echo "  Building..."
    if cargo install --path crates/termlink-cli 2>/dev/null; then
        local new_version
        new_version=$(termlink --version 2>/dev/null | head -1)
        echo -e "${GREEN}OK${NC}  TermLink updated: $new_version"
    else
        die "cargo install failed — check build output"
    fi
}

cmd_help() {
    echo -e "${BOLD}fw termlink${NC} — TermLink integration for cross-terminal communication"
    echo -e "  Repo: https://onedev.docker.ring20.geelenandcompany.com/termlink"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${GREEN}check${NC}                        Verify TermLink installation"
    echo -e "  ${GREEN}spawn${NC} --task T-XXX [--name N] Open tagged terminal session"
    echo -e "  ${GREEN}exec${NC} <session> <command>      Run command in session (structured output)"
    echo -e "  ${GREEN}status${NC}                       List active TermLink sessions"
    echo -e "  ${GREEN}cleanup${NC}                      Deregister sessions, close terminal windows"
    echo -e "  ${GREEN}dispatch${NC} --name N --prompt P  Spawn claude -p worker in real terminal
                                     [--project DIR] [--model M] [--timeout S]
                                     [--permission-mode acceptEdits]   (T-2282: MCP workers need this)
                                     [--mcp-config <path>] [--strict-mcp-config]
                                       (T-2284: pin MCP server set independent of parent trust)
                                     [--allowed-tools <list>]
                                       (T-2288: pre-approve tools for non-interactive workers
                                        e.g. \"mcp__fw__work_on mcp__fw__task_update Read Write Bash\")"
    echo -e "  ${GREEN}worker-kinds${NC}                   List the --worker-kind values dispatch accepts"
    echo -e "  ${GREEN}wait${NC} --name N [--timeout S]   Wait for worker completion"
    echo -e "  ${GREEN}result${NC} <worker-name>          Read worker result file"
    echo -e "  ${GREEN}update${NC} [--quiet]              Pull latest + rebuild (daily cron uses --quiet)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  fw termlink check"
    echo "  fw termlink spawn --task T-042 --name test-runner"
    echo "  fw termlink exec test-runner 'pytest tests/'"
    echo "  fw termlink dispatch --task T-042 --name worker-1 --prompt 'Analyze auth module'
  fw termlink dispatch --task T-042 --name tl-worker --project /opt/termlink --prompt '...'"
    echo "  fw termlink wait --all --timeout 300"
    echo "  fw termlink cleanup"
}

# T-1669 Step 2 — `fw termlink record-outcome --model X --task-type Y --exit-code N`
# Called from dispatch run.sh after the worker exits, and usable directly for
# tests / manual replay. No-op on missing args (best-effort recording).
cmd_record_outcome() {
    local model="" task_type="" exit_code="" close_state="" task=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model) model="$2"; shift 2 ;;
            --task-type) task_type="$2"; shift 2 ;;
            --exit-code) exit_code="$2"; shift 2 ;;
            --close-state) close_state="$2"; shift 2 ;;   # T-3440
            --task) task="$2"; shift 2 ;;                 # T-3440
            *) die "Unknown option: $1" ;;
        esac
    done
    _route_cache_record_outcome "$model" "$task_type" "$exit_code" "$close_state" "$task"
}

# --- Main routing ---
# T-1643/W1: skip main routing when sourced (e.g. by tests).
# `${BASH_SOURCE[0]} != $0` indicates we're being sourced, not executed.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        check)    cmd_check "$@" ;;
        spawn)    cmd_spawn "$@" ;;
        exec)     cmd_exec "$@" ;;
        status)   cmd_status "$@" ;;
        cleanup)  cmd_cleanup "$@" ;;
        worker-kinds) cmd_worker_kinds "$@" ;;
        dispatch) cmd_dispatch "$@" ;;
        wait)     cmd_wait "$@" ;;
        result)   cmd_result "$@" ;;
        update)   cmd_update "$@" ;;
        record-outcome) cmd_record_outcome "$@" ;;
        help|--help|-h) cmd_help ;;
        *) die "Unknown subcommand: $subcmd (run 'fw termlink help')" ;;
    esac
fi
