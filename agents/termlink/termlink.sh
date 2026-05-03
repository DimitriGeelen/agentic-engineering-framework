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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

DISPATCH_DIR="/tmp/tl-dispatch"
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
_route_cache_record_outcome() {
    local model="$1" task_type="$2" exit_code="$3"
    [ -n "$model" ] && [ -n "$task_type" ] && [ -n "$exit_code" ] || return 0
    command -v python3 >/dev/null 2>&1 || return 0
    local cache_file
    cache_file=$(_route_cache_path)
    local cache_dir
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir" 2>/dev/null || return 0
    [ -w "$cache_dir" ] || return 0
    python3 - "$cache_file" "$model" "$task_type" "$exit_code" <<'PY' 2>/dev/null || true
import fcntl, json, os, sys, tempfile
from datetime import datetime, timezone

cache_file, model, task_type, exit_code = (
    sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
)
key = f"{model}:{task_type}"
ok = (exit_code == "0")

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

cmd_check() {
    if command -v termlink >/dev/null 2>&1; then
        local version
        version=$(termlink --version 2>/dev/null | head -1)
        echo -e "${GREEN}OK${NC}  TermLink installed: $version"
        echo "  Path: $(command -v termlink)"
        echo "  Repo: https://onedev.docker.ring20.geelenandcompany.com/termlink"
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
            printf "  %-20s  status: %-20s  session: %s%s\n" "$name" "$status" "$session_alive" "$task_tag"
        done
        echo ""
    fi

    # Show all TermLink sessions
    echo "All TermLink sessions:"
    termlink list 2>/dev/null || echo "  None"
}

cmd_cleanup() {
    local orphan_count=0

    # T-577: Detect and kill orphaned dispatch processes
    # An orphan = dispatch worker dir exists, no exit_code file, but process may still run
    # This catches processes left behind by termlink run timeout (upstream bug) or crashes
    if [ -d "$DISPATCH_DIR" ]; then
        for wdir in "$DISPATCH_DIR"/*/; do
            [ -d "$wdir" ] || continue
            local wname
            wname=$(basename "$wdir")

            # Skip already-finished workers
            [ -f "$wdir/exit_code" ] && continue

            # Check if any processes are still running for this worker
            local worker_pids=""
            worker_pids=$(ps aux 2>/dev/null | grep "$wdir" | grep -v grep | awk '{print $2}' || true)

            if [ -n "$worker_pids" ]; then
                # T-843/T-972: Check if a claude process is actively running — if so, skip (not orphaned)
                # Must check BOTH the matched PIDs AND their child processes, because
                # run.sh (matched by grep $wdir) spawns claude -p as a child process
                # whose args don't contain $wdir.
                local has_claude=false
                for pid in $worker_pids; do
                    local cmd_line
                    cmd_line=$(ps -p "$pid" -o args= 2>/dev/null || echo "")
                    if echo "$cmd_line" | grep -q "claude"; then
                        has_claude=true
                        break
                    fi
                    # T-972: Also check child processes of this PID
                    local child_pids
                    child_pids=$(ps --ppid "$pid" -o pid= 2>/dev/null || true)
                    for cpid in $child_pids; do
                        local child_cmd
                        child_cmd=$(ps -p "$cpid" -o args= 2>/dev/null || echo "")
                        if echo "$child_cmd" | grep -q "claude"; then
                            has_claude=true
                            break 2
                        fi
                    done
                done

                if [ "$has_claude" = true ]; then
                    echo -e "${GREEN}ACTIVE${NC}  Worker '$wname' has running claude process — skipping"
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
            fi
        done
    fi

    [ "$orphan_count" -gt 0 ] && echo -e "${YELLOW}Cleaned $orphan_count orphaned worker(s)${NC}"

    [ -d "$DISPATCH_DIR" ] || {
        echo "No dispatch workers to clean up."
        command -v termlink >/dev/null 2>&1 && termlink clean 2>/dev/null || true
        return 0
    }

    # Collect tracked window IDs (macOS only)
    local window_ids=""
    for wdir in "$DISPATCH_DIR"/*/; do
        [ -d "$wdir" ] || continue
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

    rm -rf "$DISPATCH_DIR"
    [ "$orphan_count" -gt 0 ] \
        && echo "All workers cleaned up ($orphan_count orphan(s) terminated)." \
        || echo "All workers cleaned up."
}

cmd_dispatch() {
    ensure_termlink
    local task="" name="" prompt="" prompt_file="" project_dir="" timeout="$TERMLINK_WORKER_TIMEOUT" model="" task_type="" tools="" worker_kind=""
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
            *) die "Unknown option: $1" ;;
        esac
    done

    case "$worker_kind" in
        ""|claude|ollama-loop) : ;;
        *) die "Unknown --worker-kind: $worker_kind (allowed: claude, ollama-loop)" ;;
    esac

    [ -z "$name" ] && die "Missing --name"
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

    # T-1643/W3 + T-1664 + T-1669: resolve model.
    # Pre-T-1669: env-var lookup only.
    # T-1669: route_cache.best_model_for(task_type) consulted FIRST, env-var as fallback.
    # Returns "<model>|<fallback_used>|<source>".
    local _resolved
    _resolved=$(_resolve_dispatch_model_and_fallback "$model" "$task_type")
    local resolution_source
    IFS='|' read -r model fallback_used resolution_source <<< "$_resolved"
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

    # Save prompt, task tag, and metadata (from tl-dispatch.sh pattern)
    echo "$prompt" > "$wdir/prompt.md"
    [ -n "$task" ] && echo "$task" > "$wdir/task"

    # T-1700: workflow env: plumb-through. Write env.sh sourced by run.sh.
    # Keys validated at parse time (KEY=VAL with KEY ∈ [A-Z_][A-Z0-9_]*).
    # Values are written verbatim with shell-quoted form so spaces/specials survive.
    : > "$wdir/env.sh"
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
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running"
}
METAEOF

    # Worker script runs inside the spawned terminal
    # Adapted from tl-dispatch.sh — battle-tested with 3 parallel workers
    cat > "$wdir/run.sh" <<'RUNEOF'
#!/bin/bash
WORKER_NAME="$1"; PROJECT_DIR="$2"; WDIR="$3"; TIMEOUT="$4"; MODEL="$5"
TASK_TYPE="$6"; FW_BIN="$7"
cd "$PROJECT_DIR" || { echo "FATAL: cd $PROJECT_DIR failed" > "$WDIR/stderr.log"; exit 1; }

# T-792: Export PROJECT_ROOT so hooks skip git resolution and use the correct project
export PROJECT_ROOT="$PROJECT_DIR"
if [ -d "$PROJECT_DIR/.agentic-framework" ]; then
    export FRAMEWORK_ROOT="$PROJECT_DIR/.agentic-framework"
else
    export FRAMEWORK_ROOT="$PROJECT_DIR"
fi

# T-576: Unset CLAUDECODE to allow nested claude sessions from within Claude Code
unset CLAUDECODE 2>/dev/null || true

# T-1700: Source per-workflow env overrides written by cmd_dispatch (e.g.
# ANTHROPIC_BASE_URL=http://localhost:4000 for litellm/ollama dispatch).
# File contains `export KEY=value` lines, one per --env arg, escaped with %q.
# Empty when no --env passed. Sourced AFTER PROJECT_ROOT/FRAMEWORK_ROOT so those
# can be overridden too if a workflow needs it.
[ -f "$WDIR/env.sh" ] && . "$WDIR/env.sh"

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

# T-1706: worker_kind dispatch routing. If worker_kind.txt requests ollama-loop,
# run the thin tool-loop worker (curated litellm direct, ~150 LOC python). The
# python worker writes result.jsonl + result.md + exit_code itself, so we skip
# the claude -p branch entirely.
WORKER_KIND=""
[ -f "$WDIR/worker_kind.txt" ] && WORKER_KIND=$(cat "$WDIR/worker_kind.txt")

if [ "$WORKER_KIND" = "ollama-loop" ]; then
    # Resolve project's ollama-tool-loop.py — prefer FRAMEWORK_ROOT if vendored,
    # else PROJECT_ROOT/tools (framework repo case).
    LOOP_BIN=""
    for cand in "$FRAMEWORK_ROOT/tools/ollama-tool-loop.py" "$PROJECT_DIR/tools/ollama-tool-loop.py"; do
        if [ -x "$cand" ]; then LOOP_BIN="$cand"; break; fi
    done
    if [ -z "$LOOP_BIN" ]; then
        echo "FATAL: ollama-tool-loop.py not found" > "$WDIR/stderr.log"
        echo 1 > "$WDIR/exit_code"
    else
        # Pass model alias as OLLAMA_LOOP_MODEL when --model was supplied.
        [ -n "$MODEL" ] && export OLLAMA_LOOP_MODEL="$MODEL"
        ( python3 "$LOOP_BIN" --wdir "$WDIR" >"$WDIR/stdout.log" 2>"$WDIR/stderr.log" ) &
        LOOP_PID=$!
        (sleep "$TIMEOUT" && kill "$LOOP_PID" 2>/dev/null && echo "TIMEOUT" >> "$WDIR/stderr.log") &
        WATCHDOG_PID=$!
        wait "$LOOP_PID" 2>/dev/null
        EXIT_CODE=$?
        kill "$WATCHDOG_PID" 2>/dev/null || true
        # Worker already wrote exit_code; respect it. If absent, fall back.
        [ ! -f "$WDIR/exit_code" ] && echo "$EXIT_CODE" > "$WDIR/exit_code"
    fi
else
    # Background process + kill watchdog (macOS has no `timeout` command)
    # T-1663: stream-json preserves forensic trail when watchdog kills the worker — text format
    # buffers everything until completion, leaving an empty result.md on timeout (T-1643 found
    # this twice consecutively on U-005 dispatches). result.jsonl is the live trail; result.md
    # carries the final assistant text extracted on clean exit (backward-compat with `fw termlink result`).
    claude -p "$(cat "$WDIR/prompt.md")" $MODEL_FLAG $TOOLS_FLAG --output-format stream-json --verbose > "$WDIR/result.jsonl" 2>"$WDIR/stderr.log" &
    CLAUDE_PID=$!
    (sleep "$TIMEOUT" && kill "$CLAUDE_PID" 2>/dev/null && echo "TIMEOUT" >> "$WDIR/stderr.log") &
    WATCHDOG_PID=$!
    wait "$CLAUDE_PID" 2>/dev/null
    EXIT_CODE=$?
    kill "$WATCHDOG_PID" 2>/dev/null || true

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

# T-1669 Step 2: record outcome into route_cache so future dispatches can
# learn from it. Best-effort — missing model / task_type / fw skips silently.
if [ -n "$MODEL" ] && [ -n "$TASK_TYPE" ] && [ -n "$FW_BIN" ] && [ -x "$FW_BIN" ]; then
    "$FW_BIN" termlink record-outcome \
        --model "$MODEL" --task-type "$TASK_TYPE" --exit-code "$EXIT_CODE" \
        >/dev/null 2>&1 || true
fi

termlink event emit "$WORKER_NAME" worker.done \
    -p "{\"exit_code\":$EXIT_CODE,\"result\":\"$WDIR/result.md\"}" 2>/dev/null || true

echo ""
echo "=== Worker $WORKER_NAME finished (exit: $EXIT_CODE) ==="
echo "Result: $WDIR/result.md"
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
                [ -f "$wdir/exit_code" ] || { all_done=false; break; }
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
        while [ ! -f "$wdir/exit_code" ] && [ "$(date +%s)" -lt "$deadline" ]; do sleep 2; done

        if [ -f "$wdir/exit_code" ]; then
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
    [ -d "$wdir" ] || die "No dispatch directory for worker '$name'"

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

    if [ ! -d "$repo_dir/.git" ]; then
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
                                     [--project DIR] [--model M] [--timeout S]"
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
    local model="" task_type="" exit_code=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model) model="$2"; shift 2 ;;
            --task-type) task_type="$2"; shift 2 ;;
            --exit-code) exit_code="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done
    _route_cache_record_outcome "$model" "$task_type" "$exit_code"
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
        dispatch) cmd_dispatch "$@" ;;
        wait)     cmd_wait "$@" ;;
        result)   cmd_result "$@" ;;
        update)   cmd_update "$@" ;;
        record-outcome) cmd_record_outcome "$@" ;;
        help|--help|-h) cmd_help ;;
        *) die "Unknown subcommand: $subcmd (run 'fw termlink help')" ;;
    esac
fi
