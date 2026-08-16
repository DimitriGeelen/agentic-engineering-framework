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
# PID/LOG in PROJECT_ROOT so review.sh and watchtower.sh find them in the same place (T-1154)
PID_FILE="$PROJECT_ROOT/.context/working/watchtower.pid"
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

detect_lan_ip() {
    ip -4 addr show scope global 2>/dev/null \
        | grep 'inet' \
        | awk '{print $2}' \
        | cut -d/ -f1 \
        | head -n 1
}

get_pid() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    fi
}

is_running() {
    local pid
    pid=$(get_pid)
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

port_in_use() {
    local port="$1"
    ss -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null
}

# ensure_firewall_open is sourced from lib/firewall.sh (T-888)

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

    if ! kill -0 "$pid" 2>/dev/null; then
        log_warn "Stale PID file (PID $pid not running). Cleaning up."
        rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
        return 0
    fi

    log_info "Stopping Watchtower (PID $pid)..."

    # Graceful shutdown
    kill -TERM "$pid" 2>/dev/null || true
    local timeout=10
    while [ "$timeout" -gt 0 ] && kill -0 "$pid" 2>/dev/null; do
        log_info "  Waiting for shutdown... (${timeout}s)"
        sleep 1
        timeout=$((timeout - 1))
    done

    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        log_warn "Graceful shutdown failed. Sending SIGKILL..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi

    if kill -0 "$pid" 2>/dev/null; then
        log_error "Failed to stop Watchtower (PID $pid)."
        return 1
    fi

    rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
    log_info "Watchtower stopped."
}

# ---------------------------------------------------------------------------
# start — Launch Watchtower with health check
# ---------------------------------------------------------------------------
do_start() {
    local port="$DEFAULT_PORT"
    local debug_flag=""

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
        local pid
        pid=$(get_pid)
        log_warn "Watchtower is already running (PID $pid)."
        log_info "Use '$(basename "$0") restart' to restart, or '$(basename "$0") stop' first."
        return 1
    fi

    # Check Flask is installed
    if ! python3 -c "import flask" 2>/dev/null; then
        log_error "Flask is not installed."
        echo "  Install: pip install flask pyyaml ruamel.yaml markdown2 bleach" >&2
        exit 1
    fi

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
    PROJECT_ROOT="$PROJECT_ROOT" python3 -m web.app --port "$port" $debug_flag > "$LOG_FILE" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$PID_FILE"

    # Health check — wait up to 5 seconds
    local check=0
    while [ "$check" -lt 5 ]; do
        sleep 1
        check=$((check + 1))

        # Check process is still alive
        if ! kill -0 "$new_pid" 2>/dev/null; then
            log_error "Watchtower exited immediately. Last 10 lines of log:"
            tail -10 "$LOG_FILE" >&2
            rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
            exit 1
        fi

        # Check HTTP response
        if curl -sf "http://localhost:${port}/" > /dev/null 2>&1; then
            # T-1803: triple self-validation — the 200 must come from OUR instance,
            # not a foreign service that grabbed the port in a race. Only then is
            # the watchtower.{port,url} triple trustworthy. On mismatch, refuse to
            # write a triple pointing at a neighbor; kill our process and abort.
            if ! _watchtower_port_holder_is_ours "$port"; then
                log_error "Port $port responds but identifies as a FOREIGN service, not this project's Watchtower."
                log_error "  Refusing to write a triple pointing at it. Aborting."
                kill -KILL "$new_pid" 2>/dev/null || true
                rm -f "$PID_FILE" "$PORT_FILE" "$URL_FILE"
                exit 1
            fi
            log_info "Health check passed (identity verified)."
            ensure_firewall_open "$port"

            local lan_ip
            lan_ip=$(detect_lan_ip)

            # T-1287: write port + url triple atomically (Layer 1 source of truth)
            # URL prefers LAN IP for external callers; falls back to localhost.
            local url
            if [ -n "$lan_ip" ]; then
                url="http://${lan_ip}:${port}"
            else
                url="http://localhost:${port}"
            fi
            printf '%s\n' "$port" > "${PORT_FILE}.tmp" && mv "${PORT_FILE}.tmp" "$PORT_FILE"
            printf '%s\n' "$url"  > "${URL_FILE}.tmp"  && mv "${URL_FILE}.tmp"  "$URL_FILE"

            echo ""
            echo -e "${BOLD}Watchtower is running${NC}"
            echo -e "  Local:  http://localhost:${port}"
            if [ -n "$lan_ip" ]; then
                echo -e "  LAN:    http://${lan_ip}:${port}"
            fi
            echo -e "  PID:    $new_pid"
            echo -e "  Log:    $LOG_FILE"
            return 0
        fi
    done

    # Process running but not responding
    log_warn "Watchtower started (PID $new_pid) but health check failed after 5s."
    log_warn "It may still be initializing. Check: curl http://localhost:${port}/"
    log_warn "Log: $LOG_FILE"
}

# ---------------------------------------------------------------------------
# restart — Stop then start
# ---------------------------------------------------------------------------
do_restart() {
    # T-2598 (OBS-097): remember the running port BEFORE do_stop deletes the
    # triple file — a bare `restart` must come back on the SAME port, not fall
    # back to FW_PORT/3000 (which may belong to a foreign service; that failure
    # mode left no instance running at all). Explicit --port still wins.
    local prev_port=""
    [ -f "$PORT_FILE" ] && prev_port=$(cat "$PORT_FILE" 2>/dev/null)
    do_stop
    sleep 1
    case " $* " in
        *" --port"*) do_start "$@" ;;
        *)
            if [ -n "$prev_port" ]; then
                do_start --port "$prev_port" "$@"
            else
                do_start "$@"
            fi
            ;;
    esac
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
        port=$(ss -tlnp 2>/dev/null | grep "pid=${pid}" | awk '{print $4}' | grep -oE '[0-9]+' | tail -1)
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
        if [ -f "$PID_FILE" ]; then
            echo "  (Stale PID file exists — will be cleaned on next start)"
        fi
    fi
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
    if _probe=$(curl -sf --max-time 2 "http://localhost:${_p}/api/_identity" 2>/dev/null); then
        echo "  Something IS listening on localhost:${_p}, but it is not this" >&2
        echo "  project's Watchtower. Do not treat it as ours — on a multi-project" >&2
        echo "  host the same Flask app answers 200 for almost any path, so a curl" >&2
        echo "  against it passes while asserting nothing." >&2
        echo "" >&2
        echo "  Identity reported: $(printf '%s' "$_probe" | head -c 200)" >&2
        echo "  Start yours on another port: fw serve --port <N>" >&2
    else
        echo "  Nothing is listening on localhost:${_p}." >&2
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
        if [ -n "$lan_ip" ]; then
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

case "$cmd" in
    start)   do_start "$@" ;;
    stop)    do_stop ;;
    restart) do_restart "$@" ;;
    status)  do_status ;;
    port)    do_port ;;
    url)     do_url ;;
    ""|help|-h|--help)
        echo "Usage: $(basename "$0") {start|stop|restart|status|port|url} [options]"
        echo ""
        echo "Commands:"
        echo "  start   [--port N] [--debug]  Start Watchtower"
        echo "  stop                           Stop Watchtower"
        echo "  restart [--port N] [--debug]  Stop then start"
        echo "  status                         Show current state"
        echo "  port                           Print current port (triple-file source of truth; T-1376 B5)"
        echo "  url                            Print current URL (triple-file source of truth; T-1376 B5)"
        echo ""
        echo "Environment:"
        echo "  FW_PORT  Default port (default: 3000)"
        ;;
    *)
        log_error "Unknown command: $cmd"
        echo "Usage: $(basename "$0") {start|stop|restart|status|port|url}" >&2
        exit 1
        ;;
esac
