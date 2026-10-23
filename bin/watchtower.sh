#!/bin/bash
# Watchtower — Reliable start/stop/restart for the Web UI (T-250)
# Inspired by DenkraumNavigator/restart_server_prod.sh
#
# Usage:
#   bin/watchtower.sh start [--port N] [--debug]
#   bin/watchtower.sh stop
#   bin/watchtower.sh restart [--port N] [--debug]
#   bin/watchtower.sh status

set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
source "$FRAMEWORK_ROOT/lib/firewall.sh"
# T-1803: shared identity helpers (_watchtower_port_holder_is_ours,
# _watchtower_identity_matches) so the writer reuses the reader's identity check.
source "$FRAMEWORK_ROOT/lib/watchtower.sh"
source "$FRAMEWORK_ROOT/lib/pid-alive.sh"
# PID/LOG in PROJECT_ROOT so review.sh and watchtower.sh find them in the same place (T-1154)
PID_FILE="$PROJECT_ROOT/.context/working/watchtower.pid"
# T-4323: UFW rules this project's Watchtower added (one port per line); stop removes them.
FIREWALL_STATE_FILE="$PROJECT_ROOT/.context/working/watchtower.firewall"
# T-1287: port + url triple alongside pid (foundation for T-1284 3-layer discovery)
PORT_FILE="$PROJECT_ROOT/.context/working/watchtower.port"
URL_FILE="$PROJECT_ROOT/.context/working/watchtower.url"
LOG_FILE="$PROJECT_ROOT/.context/working/watchtower.log"
DEFAULT_PORT=$(fw_config "PORT" 3000)

# Colors provided by lib/colors.sh (via paths.sh chain)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[watchtower]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[watchtower]${NC} $*"; }
log_error() { echo -e "${RED}[watchtower]${NC} $*" >&2; }

# T-4332: always status 0. Callers run `lan_ip=$(detect_lan_ip)` under
# `set -euo pipefail`; with no `ip` binary or no global IPv4 (containers) the
# grep stage exits 1 and errexit killed `start` right after "Health check passed".
# Empty output already means "no LAN address" to every caller.
detect_lan_ip() {
    ip -4 addr show scope global 2>/dev/null \
        | grep 'inet' \
        | awk '{print $2}' \
        | cut -d/ -f1 \
        | head -n 1 || true
}

get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    fi
}

# T-4306: the one liveness test. `kill -0` alone succeeds on a ZOMBIE (exited,
# not reaped — common for children of a container's PID 1), so stop failed and
# start refused on a server that was already gone. A zombie is stopped.
_pid_alive() {
    fw_pid_alive "$1"
}

is_running() {
    local pid
    pid=$(get_pid)
    _pid_alive "$pid"
}

port_in_use() {
    local port="$1" n
    # T-4221: grep -c reads all of ss's output. `grep -q` exited at the first
    # match, ss took SIGPIPE, and under pipefail the 141 read as "free" (L-387).
    n=$(ss -tln 2>/dev/null | grep -c ":${port} ") || true
    [ "${n:-0}" -gt 0 ]
}

# ensure_firewall_open is sourced from lib/firewall.sh (T-888)

# T-3662 (P-01 F-28): has this project chosen a port (FW_PORT or PORT in
# .framework.yaml)? If not, every project resolved the same registry default
# and the second one on a host collided with the first.
port_configured() {
    [ -n "${FW_PORT:-}" ] || _fw_config_file_val "PORT" >/dev/null 2>&1
}

# allocate_port — first port from PORT_SCAN_BASE (100 ports) that is free or
# already held by THIS project's identified Watchtower. Foreign holders are
# skipped, never signalled. Prints the port; rc 1 when the range is exhausted.
allocate_port() {
    local base p
    base=$(fw_config "PORT_SCAN_BASE" 3000)
    [[ "$base" =~ ^[0-9]+$ ]] || base=3000
    for ((p = base; p < base + 100; p++)); do
        if ! port_in_use "$p" || _watchtower_port_holder_is_ours "$p"; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

# choose_port [EXPLICIT] — T-3876: the ONE port rule for start AND restart.
#   1. an explicit --port
#   2. the configured PORT (the operator's statement), when free or ours
#   3. the last port this project ran on ($PORT_FILE, kept across a crash or
#      reboot), when free or ours — this is what brings an UNCONFIGURED project
#      back where its links point, instead of the first free port from 3000
#   4. allocate from PORT_SCAN_BASE
# Configured before last, deliberately: after `fw config set PORT N` a bare
# restart must move to N (055 hit the opposite with the old restart rule).
# Prints "<port> <source>" (source: explicit|configured|last|allocated);
# rc 1 when nothing is available. Any choice other than a configured PORT is
# announced by the caller — a moved port breaks every link handed out.
choose_port() {
    local explicit="${1:-}" last="" p
    if [ -n "$explicit" ]; then
        echo "$explicit explicit"; return 0
    fi
    if port_configured; then
        p="$DEFAULT_PORT"
        if ! port_in_use "$p" || _watchtower_port_holder_is_ours "$p"; then
            echo "$p configured"; return 0
        fi
    fi
    [ -f "$PORT_FILE" ] && last=$(tr -d '[:space:]' < "$PORT_FILE" 2>/dev/null || true)
    if [[ "$last" =~ ^[0-9]+$ ]] && { ! port_in_use "$last" || _watchtower_port_holder_is_ours "$last"; }; then
        echo "$last last"; return 0
    fi
    if p=$(allocate_port); then
        echo "$p allocated"; return 0
    fi
    return 1
}

# persist_port PORT — record an allocated port as PORT in .framework.yaml with
# the `fw config set` writer, so restarts and `fw watchtower port` agree.
persist_port() {
    local p="$1"
    if [ ! -f "$PROJECT_ROOT/.framework.yaml" ]; then
        log_warn "No .framework.yaml — allocated port $p is not recorded (set it: fw config set PORT $p)."
        return 0
    fi
    if ( source "$FRAMEWORK_ROOT/lib/config-file.sh" && _config_set PORT "$p" ) >/dev/null 2>&1; then
        log_info "Recorded PORT: $p in .framework.yaml (per-project port, T-3662)."
    else
        log_warn "Could not record PORT $p in .framework.yaml (set it: fw config set PORT $p)."
    fi
}

# ---------------------------------------------------------------------------
# stop — Graceful shutdown with SIGTERM, fallback to SIGKILL
# ---------------------------------------------------------------------------
do_stop() {
    if [ ! -f "$PID_FILE" ]; then
        log_info "No PID file found — Watchtower not running (or not started by this script)."
        return 0
    fi

    local pid
    pid=$(get_pid)

    if ! _pid_alive "$pid"; then
        log_warn "Stale PID file (PID $pid not running). Cleaning up."
        rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
        close_recorded_firewall_rules "$FIREWALL_STATE_FILE"
        return 0
    fi

    log_info "Stopping Watchtower (PID $pid)..."

    # Graceful shutdown. T-3660: a --debug (foreground) server runs Werkzeug's
    # reloader, which serves from a CHILD of the pid on file; signal that child
    # too, or it is orphaned still holding the port. Only children of our own
    # pid are touched — never a process group, never a port holder.
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    local timeout=10
    while [ "$timeout" -gt 0 ] && _pid_alive "$pid"; do
        log_info "  Waiting for shutdown... (${timeout}s)"
        sleep 1
        timeout=$((timeout - 1))
    done

    # Force kill if still running
    if _pid_alive "$pid"; then
        log_warn "Graceful shutdown failed. Sending SIGKILL..."
        pkill -KILL -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi

    if _pid_alive "$pid"; then
        log_error "Failed to stop Watchtower (PID $pid)."
        return 1
    fi

    rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
    # T-4323: remove the UFW rule(s) start added; a stopped server serves no port.
    close_recorded_firewall_rules "$FIREWALL_STATE_FILE"
    log_info "Watchtower stopped."
}

# ---------------------------------------------------------------------------
# start — Launch Watchtower with health check
# ---------------------------------------------------------------------------
# T-4304: the modules Watchtower imports at load (python3 -m web.app). A missing one
# is a traceback AFTER the pre-flight passed, so they are checked here.
# Format: import-name|pip-name|apt-name. Derived by blocking each module in turn
# against `import web.app`: ruamel.yaml, bleach and gunicorn are NOT on the start
# path; ollama, sqlite_vec and tantivy are imported lazily and the app degrades.
WATCHTOWER_REQUIRED_MODULES=(
    "flask|flask|python3-flask"
    "flask_socketio|flask-socketio|python3-flask-socketio"
    "yaml|pyyaml|python3-yaml"
    "markdown2|markdown2|python3-markdown2"
)

# T-4304: one actionable error naming every missing required module and the
# command for this machine. Prints the command; never runs sudo or pip.
_watchtower_check_modules() {
    local entry mod pip_name apt_name cmd
    local names="" pips="" apts=""
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "Watchtower cannot start: python3 is not installed."
        return 1
    fi
    for entry in "${WATCHTOWER_REQUIRED_MODULES[@]}"; do
        IFS='|' read -r mod pip_name apt_name <<< "$entry"
        if ! python3 -c "import $mod" 2>/dev/null; then
            names="${names:+$names, }$mod"
            pips="${pips:+$pips }$pip_name"
            apts="${apts:+$apts }$apt_name"
        fi
    done
    [ -z "$names" ] && return 0
    if command -v apt-get >/dev/null 2>&1 && grep -qiE '^ID(_LIKE)?=.*(debian|ubuntu)' /etc/os-release 2>/dev/null; then
        cmd="sudo apt-get install -y $apts"
    else
        # A venv, not --break-system-packages: PEP 668 interpreters refuse the latter.
        cmd="python3 -m venv ~/.venvs/aef-watchtower && ~/.venvs/aef-watchtower/bin/pip install $pips && . ~/.venvs/aef-watchtower/bin/activate (then re-run in that shell)"
    fi
    log_error "Watchtower cannot start: missing Python module(s): $names. Install: $cmd"
    return 1
}

do_start() {
    local port=""
    local debug_flag=""
    local allocated=0

    # Parse start-specific args
    while [ $# -gt 0 ]; do
        case "$1" in
            --port|-p) port="$2"; shift 2 ;;
            --debug)   debug_flag="--debug"; shift ;;
            # T-2806: `fw serve --help` routes here, not to the top-level help
            # branch below — `--help` arrives as an ARGUMENT to start, so the
            # catch-all rejected it: "[watchtower] Unknown option: --help",
            # exit 1. Asking a command how to use it is never an error, and the
            # failure taught the opposite: an operator's onboarding agent read it
            # as "the verb does not exist" and went looking elsewhere.
            -h|--help)
                echo "Usage: fw serve [--port N] [--debug]"
                echo ""
                echo "Start the Watchtower web UI for this project."
                echo ""
                echo "Options:"
                echo "  --port N, -p N   Listen port (default: resolved per-project,"
                echo "                   not hard-coded — see 'fw watchtower port')"
                echo "  --debug          Run in the foreground with debug logging"
                echo ""
                echo "Related:"
                echo "  fw watchtower status|port|url    Inspect a running instance"
                echo "  fw watchtower stop|restart       Lifecycle"
                exit 0
                ;;
            *)         log_error "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Check if already running
    if is_running; then
        local pid run_port=""
        pid=$(get_pid)
        [ -f "$PORT_FILE" ] && run_port=$(tr -d '[:space:]' < "$PORT_FILE" 2>/dev/null || true)
        # T-3662: reuse the running server only once /api/_identity says it is
        # THIS project's — a live pid alone can be a recycled pid or a server
        # some other project now owns on that port.
        if [ -n "$run_port" ] && { [ -z "$port" ] || [ "$port" = "$run_port" ]; } \
            && _watchtower_port_holder_is_ours "$run_port"; then
            log_info "Watchtower is already running for this project (PID $pid, identity verified)."
            echo "  Local:  http://$(_watchtower_probe_host):${run_port}"
            return 0
        fi
        log_warn "Watchtower is already running (PID $pid)${run_port:+ on port $run_port}, but it was not reused."
        log_info "Use '$(basename "$0") restart' to restart, or '$(basename "$0") stop' first."
        return 1
    elif [ -f "$PID_FILE" ]; then
        # T-4306: the pid on file is gone or a zombie — stale. Keep the port file:
        # choose_port reads it as the last port (T-3876).
        log_warn "Stale PID file (PID $(get_pid) not running). Cleaning up."
        rm -f "$PID_FILE" "$URL_FILE"
    fi

    # T-3876: one port rule for start and restart (choose_port). T-3662's
    # per-project allocation is its last step.
    local _chosen _source
    if ! _chosen=$(choose_port "$port"); then
        log_error "No free port in the 100 from PORT_SCAN_BASE ($(fw_config PORT_SCAN_BASE 3000)). Start with --port N."
        exit 1
    fi
    port=${_chosen%% *}; _source=${_chosen#* }
    case "$_source" in
        last)
            if port_configured; then
                log_warn "PORT ${DEFAULT_PORT} (configured) is held by another service; back on the port this project last ran on ($port). Links to :${DEFAULT_PORT} will not reach this Watchtower."
            else
                log_info "No PORT configured; back on the port this project last ran on ($port)."
            fi ;;
        allocated)
            if port_configured; then
                log_warn "PORT ${DEFAULT_PORT} (configured) is held by another service; starting on ALLOCATED port $port instead. Links to :${DEFAULT_PORT} will not reach this Watchtower."
            else
                allocated=1
                log_info "No PORT configured for this project; allocated port $port."
            fi ;;
    esac

    # T-4304: check every module the app imports at load, not only flask
    _watchtower_check_modules || exit 1

    # Check port availability
    if port_in_use "$port"; then
        # T-1803: NEVER signal a port holder that isn't THIS project's Watchtower.
        # On a multi-project host the holder may be a neighbor's live service
        # (the T-1802 wrong-dashboard / neighbor-kill incident). Only recycle our
        # OWN stale instance — one that still identifies as ours via /api/_identity.
        # A holder we can't positively identify as ours is treated as foreign and
        # left untouched; clear our own hung instance with `stop` (PID-based).
        if ! _watchtower_port_holder_is_ours "$port"; then
            log_error "Port $port is held by a FOREIGN service (not this project's Watchtower)."
            log_error "  Refusing to send it any signal. Identify it with:"
            log_error "    ss -tlnp | grep ':${port} '"
            log_error "  Then start on another port (--port N) or stop that service yourself."
            exit 1
        fi

        log_warn "Port $port held by this project's own (stale) Watchtower. Freeing it..."
        local retry=0
        while port_in_use "$port" && [ "$retry" -lt 3 ]; do
            retry=$((retry + 1))
            log_info "  Attempt $retry/3 — sending TERM to port $port holder..."
            fuser -k -TERM "${port}/tcp" 2>/dev/null || true
            sleep 2
            if port_in_use "$port"; then
                log_info "  Sending KILL..."
                fuser -k -KILL "${port}/tcp" 2>/dev/null || true
                sleep 1
            fi
        done

        if port_in_use "$port"; then
            log_error "Port $port still in use after 3 attempts. Cannot start."
            exit 1
        fi
        log_info "Port $port freed."
    fi

    # Ensure log/pid directory exists
    mkdir -p "$(dirname "$PID_FILE")"

    # Start Watchtower
    # Pass PROJECT_ROOT so Flask serves the correct project's data (T-467)
    # T-3054: route through the shared resolver so an unset PROJECT_ROOT warns
    # instead of silently serving the framework's own .tasks/ and .context/.
    # The substitution stays — serving the framework repo is a legitimate run —
    # but it is no longer invisible to the operator who did not intend it.
    if type _watchtower_our_root >/dev/null 2>&1; then
        PROJECT_ROOT="$(_watchtower_our_root)"
    else
        PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
    fi
    export PROJECT_ROOT
    log_info "Starting Watchtower on port $port (project: $PROJECT_ROOT)..."
    cd "$FRAMEWORK_ROOT"

    # T-3660 (P-01 F-17): --debug is a FOREGROUND run. Exec the server so this
    # process IS the server: output goes to the terminal, Ctrl-C stops it, and
    # the pid file names it (exec keeps $$), so `stop` works from another shell.
    if [ -n "$debug_flag" ]; then
        echo "$$" > "$PID_FILE"
        printf '%s\n' "$port" > "$PORT_FILE"
        printf '%s\n' "http://$(_watchtower_probe_host):${port}" > "$URL_FILE"
        [ "$allocated" -eq 1 ] && persist_port "$port"
        log_info "Foreground (--debug): output below, Ctrl-C to stop."
        export FW_HOST="$(fw_config "HOST" "0.0.0.0" 2>/dev/null || echo 0.0.0.0)"
        export WATCHTOWER_URL="http://$(_watchtower_probe_host):${port}"
        exec python3 -m web.app --port "$port" --debug
    fi

    # T-4041 (GitHub #88): FW_HOST may live only in .framework.yaml; web/config.py
    # reads the environment, so hand the resolved value down. WATCHTOWER_URL is
    # exported into the server so processes Watchtower itself starts (the
    # inception decide chain) can find it instead of guessing another port.
    local _bound_host _probe
    _bound_host=$(fw_config "HOST" "0.0.0.0" 2>/dev/null || echo "0.0.0.0")
    export FW_HOST="$_bound_host"
    _probe=$(_watchtower_probe_host)
    export WATCHTOWER_URL="http://${_probe}:${port}"

    watchtower_rotate_log "$LOG_FILE" 3  # T-3627: rotate, never truncate the evidence
    # T-3660 (P-01 F-16): detach for real. A plain `&` child stays in the
    # launcher's process group and session, so closing the terminal (SIGHUP to
    # that group) killed the server. setsid gives it its own session — it is
    # not a group leader here (no job control), so setsid execs in place and
    # $! is the server's pid. nohup is the fallback where setsid is absent.
    # T-4706: setsid leaves the server in the LAUNCHER's systemd unit (a worker
    # scope, the cockpit service), and stopping that unit SIGKILLs it with no
    # record. Give it a scope of its own under FW_WATCHTOWER_SLICE (aef.slice).
    # systemd-run --scope execs in place, so $! stays the server's pid. Empty
    # prefix where systemd cannot, or FW_AGENT_SCOPE=0 (lib/agent-scope.sh).
    FW_AGENT_SCOPE_CMD=()
    if [ -f "$FRAMEWORK_ROOT/lib/agent-scope.sh" ]; then
        # shellcheck source=/dev/null
        source "$FRAMEWORK_ROOT/lib/agent-scope.sh"
        FW_AGENT_SLICE="${FW_WATCHTOWER_SLICE:-aef.slice}" \
            fw_agent_scope_prefix "watchtower" "aef-watchtower-$(date +%s)-$$"
    fi
    if command -v setsid >/dev/null 2>&1; then
        ${FW_AGENT_SCOPE_CMD[@]+"${FW_AGENT_SCOPE_CMD[@]}"} setsid python3 -m web.app --port "$port" < /dev/null > "$LOG_FILE" 2>&1 &
    else
        ${FW_AGENT_SCOPE_CMD[@]+"${FW_AGENT_SCOPE_CMD[@]}"} nohup python3 -m web.app --port "$port" < /dev/null > "$LOG_FILE" 2>&1 &
    fi
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    # Health check — T-4460: poll the cheap /api/_identity, not GET / (the home
    # page took 68 s under load), for up to WATCHTOWER_START_TIMEOUT seconds.
    local deadline
    deadline=$(fw_config "WATCHTOWER_START_TIMEOUT" "60" 2>/dev/null || echo 60)
    [[ "$deadline" =~ ^[0-9]+$ ]] && [ "$deadline" -ge 1 ] || deadline=60
    local check=0 _state
    while [ "$check" -lt "$deadline" ]; do
        sleep 1
        check=$((check + 1))

        # Check process is still alive
        if ! _pid_alive "$new_pid"; then
            log_error "Watchtower exited immediately. Last 10 lines of log:"
            tail -10 "$LOG_FILE" >&2
            rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
            exit 1
        fi

        # T-1803: triple self-validation — the answer must come from OUR instance,
        # not a foreign service that grabbed the port in a race. Only then is the
        # watchtower.{port,url} triple trustworthy. On mismatch, refuse to write a
        # triple pointing at a neighbor; kill our process and abort.
        _state=$(_watchtower_identity_state "http://${_probe}:${port}")
        if [ "$_state" != "none" ]; then
            if [ "$_state" != "ours" ]; then
                log_error "Port $port responds but identifies as a FOREIGN service, not this project's Watchtower."
                log_error "  Refusing to write a triple pointing at it. Aborting."
                kill -KILL "$new_pid" 2>/dev/null || true
                rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
                exit 1
            fi
            log_info "Health check passed (identity verified)."
            [ "$allocated" -eq 1 ] && persist_port "$port"
            # T-4297: pass the bind host (loopback never touches UFW) and honour the
            # operator's opt-in from config; without it nothing is opened.
            FW_WATCHTOWER_OPEN_FIREWALL="${FW_WATCHTOWER_OPEN_FIREWALL:-$(fw_config "WATCHTOWER_OPEN_FIREWALL" "0" 2>/dev/null || echo 0)}" \
                ensure_firewall_open "$port" "Agentic Framework" "${FW_HOST:-0.0.0.0}" "$FIREWALL_STATE_FILE"

            local lan_ip
            lan_ip=$(detect_lan_ip)

            # T-1287: write port + url triple atomically (Layer 1 source of truth)
            # URL prefers LAN IP for external callers; falls back to localhost.
            local url
            if _watchtower_bound_host >/dev/null; then
                url="http://${_probe}:${port}"   # T-4041: bound to one address
            elif [ -n "$lan_ip" ]; then
                url="http://${lan_ip}:${port}"
            else
                url="http://localhost:${port}"
            fi
            printf '%s\n' "$port" > "${PORT_FILE}.tmp" && mv "${PORT_FILE}.tmp" "$PORT_FILE"
            printf '%s\n' "$url"  > "${URL_FILE}.tmp"  && mv "${URL_FILE}.tmp"  "$URL_FILE"

            echo ""
            echo -e "${BOLD}Watchtower is running${NC}"
            echo -e "  Local:  http://${_probe}:${port}"
            if [ -n "$lan_ip" ] && ! _watchtower_bound_host >/dev/null; then
                echo -e "  LAN:    http://${lan_ip}:${port}"
            fi
            echo -e "  PID:    $new_pid"
            echo -e "  Log:    $LOG_FILE"
            return 0
        fi
    done

    # T-4460: running but never identified itself. Do not leave a server behind
    # with a half-written triple (pid/port but no url): every URL reader would
    # then report "no running Watchtower" while one holds the port. Stop it.
    log_error "Watchtower (PID $new_pid) did not answer /api/_identity within ${deadline}s; stopping it."
    log_error "  Raise the deadline under load: bin/fw config set WATCHTOWER_START_TIMEOUT <seconds>"
    log_error "  Last 10 lines of $LOG_FILE:"
    tail -10 "$LOG_FILE" >&2 || true
    kill -TERM "$new_pid" 2>/dev/null || true
    sleep 1
    kill -KILL "$new_pid" 2>/dev/null || true
    rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
    exit 1
}

# ---------------------------------------------------------------------------
# restart — Stop then start
# ---------------------------------------------------------------------------
do_restart() {
    # T-2598 (OBS-097): remember the running port BEFORE do_stop deletes the
    # triple file — a bare `restart` must come back on the SAME port, not fall
    # back to FW_PORT/3000 (which may belong to a foreign service; that failure
    # mode left no instance running at all). Explicit --port still wins.
    # T-3876: no rule of its own any more — do_start's choose_port reads the
    # last port first. Keep the value across do_stop, which deletes the triple.
    local prev_port=""
    [ -f "$PORT_FILE" ] && prev_port=$(cat "$PORT_FILE" 2>/dev/null)
    do_stop
    sleep 1
    if [ -n "$prev_port" ] && [ ! -f "$PORT_FILE" ]; then
        mkdir -p "$(dirname "$PORT_FILE")"
        printf '%s\n' "$prev_port" > "$PORT_FILE"
    fi
    do_start "$@"
}

# ---------------------------------------------------------------------------
# status — Show current state
# ---------------------------------------------------------------------------
do_status() {
    if is_running; then
        local pid
        pid=$(get_pid)
        echo -e "${GREEN}Watchtower is running${NC} (PID $pid)"

        # Find the port from the process
        local port
        # T-4337: `|| true` — ss missing or no match must not exit status
        # silently under set -euo pipefail (same class as T-4332).
        port=$(ss -tlnp 2>/dev/null | grep "pid=${pid}" | awk '{print $4}' | grep -oE '[0-9]+' | tail -1) || true
        if [ -n "$port" ]; then
            echo "  Local:  http://localhost:${port}"
            local lan_ip
            lan_ip=$(detect_lan_ip)
            if [ -n "$lan_ip" ]; then
                echo "  LAN:    http://${lan_ip}:${port}"
            fi
        fi
        echo "  PID:    $pid"
        echo "  Log:    $LOG_FILE"

        # Uptime
        if [ -f "/proc/$pid/stat" ]; then
            local start_time
            start_time=$(stat -c %Y "/proc/$pid" 2>/dev/null)
            if [ -n "$start_time" ]; then
                local now
                now=$(date +%s)
                local uptime=$((now - start_time))
                local hours=$((uptime / 3600))
                local mins=$(( (uptime % 3600) / 60 ))
                echo "  Uptime: ${hours}h ${mins}m"
            fi
        fi
    else
        echo -e "${YELLOW}Watchtower is not running${NC}"
        # T-3661 (P-01 F-25): status is a predicate scripts branch on, so the
        # stopped states must not exit 0. LSB init-script codes.
        if [ -f "$PID_FILE" ]; then
            echo "  (Stale PID file exists — will be cleaned on next start)"
            return 1
        fi
        return 3
    fi
}

# ---------------------------------------------------------------------------
# do_reachable — Does THIS project's Watchtower answer at its URL? (T-4562)
# ---------------------------------------------------------------------------
# Resolves the URL itself (do_url) and probes /api/_identity, so a caller needs
# no `WURL=$(cat …); curl "$WURL"` — a shape the no-focus read-only gate refuses
# (T-4512). Identity, not mere reachability: on a shared host another project's
# Watchtower answers 200 too (the T-2732 false-green class).
# rc 0 = ours, answering; 1 = a foreign service answers there; 3 = nothing answers.
do_reachable() {
    local url state
    url=$(do_url)
    state=$(_watchtower_identity_state "$url")
    case "$state" in
        ours)    echo "running at $url" ;;
        foreign) echo "stopped (something else answers at $url — not this project's Watchtower)"; return 1 ;;
        *)       echo "stopped"; return 3 ;;
    esac
}

# ---------------------------------------------------------------------------
# do_current — Is the RUNNING process serving the code on disk? (T-3282, G-104)
# ---------------------------------------------------------------------------
# rc 0 = current, OR no Watchtower running (nothing can be stale — this keeps
#        the verb safe inside ## Verification blocks on headless/CI/worktree
#        hosts, same scoping idea as `command -v dotnet && dotnet build`).
# rc 1 = the running process predates at least one file under web/ — every
#        web/ change since it started is inert, including operator-facing
#        fixes already closed green. Both prior incidents (T-2938, T-3282)
#        polluted a live human decision this way.
do_current() {
    local pid=""
    # set -euo pipefail is active: a missing pid file must read as "not
    # running", not abort the script mid-verdict.
    [ -f "$PID_FILE" ] && pid=$(tr -d '[:space:]' < "$PID_FILE" 2>/dev/null || true)
    if [ -z "$pid" ] || ! _pid_alive "$pid"; then
        log_info "current: no Watchtower running — nothing to be stale"
        return 0
    fi
    # shellcheck source=/dev/null
    . "$FRAMEWORK_ROOT/lib/watchtower-staleness.sh"
    local stale web_dir rc=0
    web_dir=$(watchtower_web_dir)
    stale=$(watchtower_stale_sources "$pid" "$web_dir") || rc=$?
    if [ "$rc" -eq 0 ]; then
        log_error "STALE: Watchtower pid $pid predates $(printf '%s\n' "$stale" | grep -c .) file(s) under $web_dir"
        printf '%s\n' "$stale" | head -5 | sed 's|^|  - |' >&2
        log_error "Every web/ change since it started is inert. Run: bin/fw watchtower restart"
        return 1
    fi
    if [ "$rc" -eq 2 ]; then
        # T-4132: a running server whose web tree we cannot find is NOT current.
        log_error "CANNOT TELL: Watchtower pid $pid is running but $web_dir does not exist"
        return 1
    fi
    log_info "current: Watchtower pid $pid is newer than every file under $web_dir"
    return 0
}

# ---------------------------------------------------------------------------
# do_port / do_url — Public accessors for triple-file source-of-truth (T-1376 B5)
# ---------------------------------------------------------------------------
do_port() {
    if [ -f "$PORT_FILE" ]; then
        cat "$PORT_FILE"
    else
        fw_config "PORT" "$DEFAULT_PORT"
    fi
}

# T-2802: what to say when we cannot identify a Watchtower of ours. Distinguishes
# the two states an unverified port can be in, because they have different fixes
# and the old code reported neither: nothing is listening (start one) vs. someone
# ELSE is listening (do not curl it — that is the 371-line false-green class).
_url_refuse() {
    local _p="$1"
    local _probe
    log_error "Cannot identify a Watchtower for this project."
    # PROJECT_ROOT is always set here — lib/paths.sh:39-46 falls back to
    # FRAMEWORK_ROOT — so naming it is the useful thing to print: on a
    # multi-project host, "which project am I actually being asked about" is
    # half the answer.
    echo "  Project: $PROJECT_ROOT" >&2
    if _probe=$(curl -sf --max-time 2 "http://$(_watchtower_probe_host):${_p}/api/_identity" 2>/dev/null); then
        echo "  Something IS listening on $(_watchtower_probe_host):${_p}, but it is not this" >&2
        echo "  project's Watchtower. Do not treat it as ours — on a multi-project" >&2
        echo "  host the same Flask app answers 200 for almost any path, so a curl" >&2
        echo "  against it passes while asserting nothing." >&2
        echo "" >&2
        echo "  Identity reported: $(printf '%s' "$_probe" | head -c 200)" >&2
        echo "  Start yours on another port: fw serve --port <N>" >&2
    else
        echo "  Nothing is listening on $(_watchtower_probe_host):${_p}." >&2
        echo "  Start one with: fw serve" >&2
    fi
    echo "  Or set WATCHTOWER_URL explicitly." >&2
    return 1
}

do_url() {
    # T-2802: env override first, for parity with lib/watchtower.sh's
    # _watchtower_url — a caller who states the answer is not guessing.
    if [ -n "${WATCHTOWER_URL:-}" ]; then
        echo "$WATCHTOWER_URL"
        return 0
    fi

    # T-1622: when running, regenerate LAN URL from current detect_lan_ip — the
    # cached URL_FILE goes stale on DHCP IP rotation (T-1621). Witness: this host
    # bounced between .123 and .107 8x in one day, file kept first-write value
    # for hours, every emitted review URL 404'd from LAN clients. File remains
    # the fallback for the stopped state, so handover artefacts still surface
    # "where it WAS running."
    if is_running; then
        local p lan_ip
        p=$(do_port)
        lan_ip=$(detect_lan_ip)
        if _watchtower_bound_host >/dev/null; then
            echo "http://$(_watchtower_probe_host):${p}"   # T-4041
        elif [ -n "$lan_ip" ]; then
            echo "http://${lan_ip}:${p}"
        else
            echo "http://localhost:${p}"
        fi
    elif [ -f "$URL_FILE" ]; then
        # Written by our own start (triple-file), so it is project-scoped by
        # construction: "where it WAS running". Stale, but never someone else's.
        cat "$URL_FILE"
    else
        # T-2802: this used to be `echo "http://localhost:$(fw_config PORT 3000)"`
        # — a guess wearing the shape of an answer. lib/watchtower.sh's
        # _watchtower_url has refused to do that since T-1803 ("never return a URL
        # to a service we didn't positively identify"); this accessor, the one
        # CLAUDE.md puts inside ## Verification blocks, kept doing it.
        local p
        p=$(fw_config "PORT" "$DEFAULT_PORT")
        _url_refuse "$p"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Main dispatch
# ---------------------------------------------------------------------------
cmd="${1:-}"
shift || true

# T-4706: a test must never start, stop or restart the Watchtower of the checkout
# it runs from — that is the operator's live server (2026-10-23: down ~1h47m,
# nothing noticed). Under bats or pytest the "live checkout" is the git toplevel
# of the test file (bats) or of the cwd (pytest); a test points PROJECT_ROOT at a
# temp project instead. FW_WATCHTOWER_ALLOW_LIVE_IN_TEST=1 overrides.
_watchtower_live_test_refusal() {
    [ -n "${BATS_TEST_FILENAME:-}${PYTEST_CURRENT_TEST:-}" ] || return 0
    [ "${FW_WATCHTOWER_ALLOW_LIVE_IN_TEST:-0}" = 1 ] && return 0
    local from live ours
    if [ -n "${BATS_TEST_FILENAME:-}" ]; then from=$(dirname "$BATS_TEST_FILENAME"); else from=$PWD; fi
    live=$(git -C "$from" rev-parse --show-toplevel 2>/dev/null) || return 0
    live=$(readlink -f "$live" 2>/dev/null || echo "$live")
    ours=$(readlink -f "$PROJECT_ROOT" 2>/dev/null || echo "$PROJECT_ROOT")
    [ "$ours" = "$live" ] || return 0
    log_error "Refusing '$1' from a test: PROJECT_ROOT is the live checkout ($live) — its Watchtower is the operator's (T-4706)."
    log_error "  Point PROJECT_ROOT at a temp project, or set FW_WATCHTOWER_ALLOW_LIVE_IN_TEST=1."
    exit 4
}
case "$cmd" in
    start|stop|restart|ensure) _watchtower_live_test_refusal "$cmd" ;;
esac

# T-4711: a Watchtower run by a systemd .service unit is systemd's. start would put a
# second, unmanaged server in its own scope; restart would stop systemd's and do the
# same. Refuse both and name the unit (rule: fw_watchtower_systemd_unit).
_watchtower_systemd_refusal() {
    local unit
    # shellcheck source=/dev/null
    . "$FRAMEWORK_ROOT/lib/watchtower-ensure.sh"
    unit=$(PROJECT_ROOT="$PROJECT_ROOT" fw_watchtower_systemd_unit) || return 0
    log_error "Refusing '$1': this project's Watchtower is managed by systemd unit $unit (T-4711)."
    log_error "  Use: systemctl $1 $unit"
    exit 5
}
case "$cmd" in
    start|restart)
        case " $* " in *" -h "*|*" --help "*) ;; *) _watchtower_systemd_refusal "$cmd" ;; esac ;;
esac

case "$cmd" in
    # T-4706: the cron keep-alive. Starts a dead Watchtower and records the outage
    # (lib/watchtower-ensure.sh); `fw doctor` WARNs on a recent one.
    ensure)
        # shellcheck source=/dev/null
        . "$FRAMEWORK_ROOT/lib/watchtower-ensure.sh"
        export PROJECT_ROOT FRAMEWORK_ROOT
        FW_WATCHTOWER_ENSURE_BY="${FW_WATCHTOWER_ENSURE_BY:-cron}" fw_watchtower_ensure
        ;;
    start)   do_start "$@" ;;
    stop)    do_stop ;;
    restart) do_restart "$@" ;;
    status)  do_status ;;
    reachable) do_reachable ;;
    port)    do_port ;;
    url)     do_url ;;
    current) do_current ;;
    ""|help|-h|--help)
        echo "Usage: $(basename "$0") {start|stop|restart|status|port|url} [options]"
        echo ""
        echo "Commands:"
        echo "  start   [--port N] [--debug]  Start Watchtower"
        echo "  stop                           Stop Watchtower"
        echo "  restart [--port N] [--debug]  Stop then start"
        echo "  status                         Show current state; exit 0 running, 1 stale PID file, 3 not running (T-3661)"
        echo "  reachable                      Probe this project's Watchtower at its URL; exit 0 running, 1 foreign, 3 stopped (T-4562)"
        echo "  port                           Print current port (triple-file source of truth; T-1376 B5)"
        echo "  url                            Print current URL (triple-file source of truth; T-1376 B5)"
        echo "  current                        Exit 1 if the running process predates web/ source (T-3282)"
        echo "  ensure                         Start it if dead and record the outage (cron keep-alive; T-4706)"
        echo ""
        echo "Environment:"
        echo "  FW_PORT  Default port (default: 3000)"
        echo "  FW_HOST  Bind address (default: 0.0.0.0 = all interfaces). A specific address is"
        echo "           what start probes, writes to the url file and exports as WATCHTOWER_URL"
        ;;
    *)
        log_error "Unknown command: $cmd"
        echo "Usage: $(basename "$0") {start|stop|restart|status|port|url}" >&2
        exit 1
        ;;
esac
