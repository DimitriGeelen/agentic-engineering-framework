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

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

DISPATCH_DIR="/tmp/tl-dispatch"

die() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }

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
    local task="" name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [ -z "$name" ] && name="worker-$(date +%s)"

    local wdir="$DISPATCH_DIR/$name"
    mkdir -p "$wdir"
    [ -n "$task" ] && echo "$task" > "$wdir/task"

    # Delegate to termlink spawn — it handles platform detection, shell init
    # timing, and wait-for-registration natively. (GH #9: the old code
    # reimplemented these primitives and introduced two bugs.)
    local spawn_args=(--name "$name" --wait --wait-timeout 30)
    [ -n "$task" ] && spawn_args+=(--tags "task=$task")
    spawn_args+=(--shell)

    termlink spawn "${spawn_args[@]}"
    echo -e "${GREEN}OK${NC}  Session '$name' registered"
    [ -n "$task" ] && echo "  Tagged: $task"
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
    echo "All workers cleaned up."
}

cmd_dispatch() {
    ensure_termlink
    local task="" name="" prompt="" prompt_file="" project_dir="" timeout=600

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --prompt) prompt="$2"; shift 2 ;;
            --prompt-file) prompt_file="$2"; shift 2 ;;
            --project) project_dir="$2"; shift 2 ;;
            --timeout) timeout="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    [ -z "$name" ] && die "Missing --name"
    [ -z "$prompt" ] && [ -z "$prompt_file" ] && die "Missing --prompt or --prompt-file"

    if [ -n "$prompt_file" ]; then
        [ -f "$prompt_file" ] || die "Prompt file not found: $prompt_file"
        prompt=$(cat "$prompt_file")
    fi

    project_dir="${project_dir:-$(pwd)}"
    local wdir="$DISPATCH_DIR/$name"
    mkdir -p "$wdir"

    # Save prompt, task tag, and metadata (from tl-dispatch.sh pattern)
    echo "$prompt" > "$wdir/prompt.md"
    [ -n "$task" ] && echo "$task" > "$wdir/task"
    cat > "$wdir/meta.json" <<METAEOF
{
  "name": "$name",
  "project": "$project_dir",
  "timeout": $timeout,
  "task": "${task:-}",
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running"
}
METAEOF

    # Worker script runs inside the spawned terminal
    # Adapted from tl-dispatch.sh — battle-tested with 3 parallel workers
    cat > "$wdir/run.sh" <<'RUNEOF'
#!/bin/bash
WORKER_NAME="$1"; PROJECT_DIR="$2"; WDIR="$3"; TIMEOUT="$4"
cd "$PROJECT_DIR"

# Background process + kill watchdog (macOS has no `timeout` command)
claude -p "$(cat "$WDIR/prompt.md")" --output-format text > "$WDIR/result.md" 2>"$WDIR/stderr.log" &
CLAUDE_PID=$!
(sleep "$TIMEOUT" && kill "$CLAUDE_PID" 2>/dev/null && echo "TIMEOUT" > "$WDIR/stderr.log") &
WATCHDOG_PID=$!
wait "$CLAUDE_PID" 2>/dev/null
EXIT_CODE=$?
kill "$WATCHDOG_PID" 2>/dev/null || true

echo "$EXIT_CODE" > "$WDIR/exit_code"
date -u +%Y-%m-%dT%H:%M:%SZ > "$WDIR/finished_at"
termlink event emit "$WORKER_NAME" worker.done \
    -p "{\"exit_code\":$EXIT_CODE,\"result\":\"$WDIR/result.md\"}" 2>/dev/null || true

echo ""
echo "=== Worker $WORKER_NAME finished (exit: $EXIT_CODE) ==="
echo "Result: $WDIR/result.md"
RUNEOF
    chmod +x "$wdir/run.sh"

    # Spawn terminal session
    cmd_spawn ${task:+--task "$task"} --name "$name"

    # Inject worker script via pty inject (fire-and-forget, NOT interact — claude takes minutes)
    sleep 1
    termlink pty inject "$name" "bash $wdir/run.sh '$name' '$project_dir' '$wdir' '$timeout'" --enter >/dev/null 2>&1

    echo "Worker spawned: $name (wdir: $wdir)"
}

cmd_wait() {
    ensure_termlink
    local name="" wait_all=false timeout=600

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
    remote_head=$(git rev-parse @{u} 2>/dev/null || echo "unknown")

    if [ "$local_head" = "$remote_head" ]; then
        $quiet || echo -e "${GREEN}OK${NC}  TermLink is up to date ($(git log --oneline -1))"
        return 0
    fi

    if $quiet; then
        echo -e "${YELLOW}UPDATE${NC}  TermLink update available"
        echo "  Local:  $(git log --oneline -1)"
        echo "  Remote: $(git log --oneline -1 @{u})"
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
    echo -e "  ${GREEN}dispatch${NC} --name N --prompt P  Spawn claude -p worker in real terminal"
    echo -e "  ${GREEN}wait${NC} --name N [--timeout S]   Wait for worker completion"
    echo -e "  ${GREEN}result${NC} <worker-name>          Read worker result file"
    echo -e "  ${GREEN}update${NC} [--quiet]              Pull latest + rebuild (daily cron uses --quiet)"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  fw termlink check"
    echo "  fw termlink spawn --task T-042 --name test-runner"
    echo "  fw termlink exec test-runner 'pytest tests/'"
    echo "  fw termlink dispatch --task T-042 --name worker-1 --prompt 'Analyze auth module'"
    echo "  fw termlink wait --all --timeout 300"
    echo "  fw termlink cleanup"
}

# --- Main routing ---

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
    help|--help|-h) cmd_help ;;
    *) die "Unknown subcommand: $subcmd (run 'fw termlink help')" ;;
esac
