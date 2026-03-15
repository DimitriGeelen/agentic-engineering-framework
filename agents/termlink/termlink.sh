#!/bin/bash
# termlink.sh — Framework wrapper for TermLink cross-terminal communication
#
# Provides: check, spawn, exec, status, cleanup, dispatch, wait, result
# TermLink is optional — all commands fail gracefully if not installed.
#
# Part of: Agentic Engineering Framework (T-502 Phase 0)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DISPATCH_DIR="/tmp/tl-dispatch"

die() { echo -e "${RED}ERROR:${NC} $1" >&2; exit 1; }

# --- Prerequisite check ---

ensure_termlink() {
    command -v termlink >/dev/null 2>&1 || die "termlink not found on PATH (install: cargo install termlink)"
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
        return 0
    else
        echo -e "${YELLOW}WARN${NC}  TermLink not installed"
        echo "  Install: cargo install termlink"
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

    # Store task tag for status display
    [ -n "$task" ] && echo "$task" > "$wdir/task"

    # Platform-specific terminal spawn
    if is_macos; then
        local spawn_output
        spawn_output=$(osascript -e "tell application \"Terminal\" to do script \"termlink register --name $name --shell${task:+ --tag task=$task}\"" 2>&1)
        local wid
        wid=$(echo "$spawn_output" | sed -n 's/.*window id \([0-9]*\).*/\1/p' | head -1)
        [ -n "$wid" ] && echo "$wid" > "$wdir/window_id"
    else
        # Linux: try common terminal emulators
        local term_cmd=""
        if command -v gnome-terminal >/dev/null 2>&1; then
            term_cmd="gnome-terminal -- bash -c 'termlink register --name $name --shell${task:+ --tag task=$task}; exec bash'"
        elif command -v x-terminal-emulator >/dev/null 2>&1; then
            term_cmd="x-terminal-emulator -e bash -c 'termlink register --name $name --shell${task:+ --tag task=$task}; exec bash'"
        elif command -v xterm >/dev/null 2>&1; then
            term_cmd="xterm -e bash -c 'termlink register --name $name --shell${task:+ --tag task=$task}; exec bash'"
        else
            die "No supported terminal emulator found (need gnome-terminal, x-terminal-emulator, or xterm)"
        fi
        eval "$term_cmd" &
    fi

    # Wait for session registration
    echo -n "Waiting for session '$name' to register..."
    local found=false
    for i in $(seq 1 15); do
        if termlink list 2>/dev/null | grep -q "$name"; then
            found=true
            break
        fi
        echo -n "."
        sleep 1
    done
    echo ""

    if [ "$found" = true ]; then
        echo -e "${GREEN}OK${NC}  Session '$name' registered"
        [ -n "$task" ] && echo "  Tagged: $task"
    else
        die "Session '$name' did not register within 15s"
    fi
}

cmd_exec() {
    ensure_termlink
    local session="${1:-}"
    shift || true
    local command_str="$*"

    [ -z "$session" ] && die "Usage: fw termlink exec <session> <command>"
    [ -z "$command_str" ] && die "Usage: fw termlink exec <session> <command>"

    # Use termlink interact with JSON output
    local result
    local start_ms
    start_ms=$(date +%s%3N 2>/dev/null || date +%s)

    if result=$(termlink interact "$session" "$command_str" --json 2>/dev/null); then
        local end_ms
        end_ms=$(date +%s%3N 2>/dev/null || date +%s)
        local elapsed=$((end_ms - start_ms))
        echo "$result" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    data['elapsed_ms'] = $elapsed
    print(json.dumps(data))
except:
    print(json.dumps({'output': sys.stdin.read(), 'exit_code': 0, 'elapsed_ms': $elapsed}))
" 2>/dev/null || echo "$result"
    else
        die "Failed to execute command in session '$session'"
    fi
}

cmd_status() {
    ensure_termlink

    echo -e "${BOLD}TermLink Sessions${NC}"
    echo ""

    local sessions
    sessions=$(termlink list --json 2>/dev/null || echo "[]")

    echo "$sessions" | python3 -c "
import sys, json, os

DISPATCH_DIR = '$DISPATCH_DIR'

try:
    sessions = json.load(sys.stdin)
except:
    sessions = []

if not sessions:
    print('  No active sessions')
    sys.exit(0)

for s in sessions:
    name = s.get('name', '?')
    role = s.get('role', '?')
    tags = s.get('tags', {})
    task = tags.get('task', '')

    # Check dispatch dir for additional metadata
    task_file = os.path.join(DISPATCH_DIR, name, 'task')
    if not task and os.path.isfile(task_file):
        with open(task_file) as f:
            task = f.read().strip()

    task_str = f' [{task}]' if task else ''
    print(f'  {name} ({role}){task_str}')

print(f'\n  Total: {len(sessions)} session(s)')
" 2>/dev/null || termlink list 2>/dev/null
}

cmd_cleanup() {
    ensure_termlink

    if [ ! -d "$DISPATCH_DIR" ]; then
        echo "No dispatch workers to clean up."
        termlink clean 2>/dev/null || true
        return 0
    fi

    # Collect window IDs (macOS only)
    local window_ids=""
    for wdir in "$DISPATCH_DIR"/*/; do
        [ -d "$wdir" ] || continue
        [ -f "$wdir/window_id" ] && window_ids="${window_ids:+$window_ids }$(cat "$wdir/window_id")"
    done

    # Deregister TermLink sessions
    termlink clean 2>/dev/null || true

    if is_macos && [ -n "$window_ids" ]; then
        # Phase 1: Kill child processes via TTY
        echo "Phase 1: Killing child processes..."
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

        # Phase 2: Graceful shell exit
        echo "Phase 2: Exiting shells..."
        for wid in $window_ids; do
            osascript -e "tell application \"Terminal\" to try
                do script \"exit\" in window id $wid
            end try" 2>/dev/null || true
        done
        sleep 2

        # Phase 3: Close remaining windows by reference
        echo "Phase 3: Closing windows..."
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
    echo -e "${GREEN}OK${NC}  Cleanup complete"
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

    # Save prompt and task tag
    echo "$prompt" > "$wdir/prompt.md"
    [ -n "$task" ] && echo "$task" > "$wdir/task"

    # Worker script that runs inside the spawned terminal
    cat > "$wdir/run.sh" <<'RUNEOF'
#!/bin/bash
WORKER_NAME="$1"; PROJECT_DIR="$2"; WDIR="$3"; TIMEOUT="$4"
cd "$PROJECT_DIR"

# Background process + watchdog for timeout
claude -p "$(cat "$WDIR/prompt.md")" --output-format text > "$WDIR/result.md" 2>"$WDIR/stderr.log" &
CLAUDE_PID=$!
(sleep "$TIMEOUT" && kill "$CLAUDE_PID" 2>/dev/null) &
WATCHDOG_PID=$!
wait "$CLAUDE_PID" 2>/dev/null
EXIT_CODE=$?
kill "$WATCHDOG_PID" 2>/dev/null || true

echo "$EXIT_CODE" > "$WDIR/exit_code"
termlink event emit "$WORKER_NAME" worker.done \
    -p "{\"exit_code\":$EXIT_CODE,\"result\":\"$WDIR/result.md\"}" 2>/dev/null || true
RUNEOF
    chmod +x "$wdir/run.sh"

    # Spawn terminal session
    cmd_spawn ${task:+--task "$task"} --name "$name"

    # Inject worker script (fire-and-forget)
    sleep 1
    termlink pty inject "$name" "bash $wdir/run.sh '$name' '$project_dir' '$wdir' '$timeout'" --enter >/dev/null 2>&1

    echo -e "${GREEN}OK${NC}  Worker '$name' dispatched"
    echo "  Project: $project_dir"
    echo "  Timeout: ${timeout}s"
    echo "  Result:  $wdir/result.md"
}

cmd_wait() {
    ensure_termlink
    local name="" wait_all=false timeout=300

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name) name="$2"; shift 2 ;;
            --all) wait_all=true; shift ;;
            --timeout) timeout="$2"; shift 2 ;;
            *) die "Unknown option: $1" ;;
        esac
    done

    if [ "$wait_all" = true ]; then
        # Wait for all workers in dispatch dir
        [ -d "$DISPATCH_DIR" ] || die "No dispatch directory — nothing to wait for"
        local workers=()
        for wdir in "$DISPATCH_DIR"/*/; do
            [ -d "$wdir" ] || continue
            workers+=("$(basename "$wdir")")
        done
        [ ${#workers[@]} -eq 0 ] && die "No workers found"

        echo "Waiting for ${#workers[@]} worker(s) (timeout: ${timeout}s)..."
        local remaining=("${workers[@]}")
        local deadline=$(($(date +%s) + timeout))

        while [ ${#remaining[@]} -gt 0 ] && [ "$(date +%s)" -lt "$deadline" ]; do
            local still_waiting=()
            for w in "${remaining[@]}"; do
                if [ -f "$DISPATCH_DIR/$w/exit_code" ]; then
                    local ec
                    ec=$(cat "$DISPATCH_DIR/$w/exit_code")
                    echo -e "  ${GREEN}DONE${NC}  $w (exit: $ec)"
                else
                    still_waiting+=("$w")
                fi
            done
            remaining=("${still_waiting[@]}")
            [ ${#remaining[@]} -gt 0 ] && sleep 2
        done

        if [ ${#remaining[@]} -gt 0 ]; then
            echo -e "${YELLOW}WARN${NC}  ${#remaining[@]} worker(s) timed out: ${remaining[*]}"
            return 1
        fi
        echo -e "${GREEN}OK${NC}  All workers completed"
    else
        [ -z "$name" ] && die "Missing --name (or use --all)"

        echo "Waiting for worker '$name' (timeout: ${timeout}s)..."
        local deadline=$(($(date +%s) + timeout))

        while [ "$(date +%s)" -lt "$deadline" ]; do
            if [ -f "$DISPATCH_DIR/$name/exit_code" ]; then
                local ec
                ec=$(cat "$DISPATCH_DIR/$name/exit_code")
                echo -e "${GREEN}OK${NC}  Worker '$name' completed (exit: $ec)"
                return 0
            fi
            sleep 2
        done

        echo -e "${RED}TIMEOUT${NC}  Worker '$name' did not complete within ${timeout}s"
        return 1
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

cmd_help() {
    echo -e "${BOLD}fw termlink${NC} — TermLink integration for cross-terminal communication"
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
    help|--help|-h) cmd_help ;;
    *) die "Unknown subcommand: $subcmd (run 'fw termlink help')" ;;
esac
