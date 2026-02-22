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
PID_FILE="$FRAMEWORK_ROOT/.context/working/watchtower.pid"
LOG_FILE="$FRAMEWORK_ROOT/.context/working/watchtower.log"
DEFAULT_PORT="${FW_PORT:-3000}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

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
        rm -f "$PID_FILE"
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

    rm -f "$PID_FILE"
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
        log_warn "Port $port is in use. Attempting to free it..."
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
    log_info "Starting Watchtower on port $port..."
    cd "$FRAMEWORK_ROOT"
    python3 -m web.app --port "$port" $debug_flag > "$LOG_FILE" 2>&1 &
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
            rm -f "$PID_FILE"
            exit 1
        fi

        # Check HTTP response
        if curl -sf "http://localhost:${port}/" > /dev/null 2>&1; then
            log_info "Health check passed."
            echo ""
            echo -e "${BOLD}Watchtower is running${NC}"
            echo -e "  Local:  http://localhost:${port}"
            local lan_ip
            lan_ip=$(detect_lan_ip)
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
    do_stop
    sleep 1
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
        port=$(ss -tlnp 2>/dev/null | grep "pid=${pid}" | awk '{print $4}' | grep -oP ':\K[0-9]+' | head -1)
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
# Main dispatch
# ---------------------------------------------------------------------------
cmd="${1:-}"
shift || true

case "$cmd" in
    start)   do_start "$@" ;;
    stop)    do_stop ;;
    restart) do_restart "$@" ;;
    status)  do_status ;;
    ""|help|-h|--help)
        echo "Usage: $(basename "$0") {start|stop|restart|status} [options]"
        echo ""
        echo "Commands:"
        echo "  start   [--port N] [--debug]  Start Watchtower"
        echo "  stop                           Stop Watchtower"
        echo "  restart [--port N] [--debug]  Stop then start"
        echo "  status                         Show current state"
        echo ""
        echo "Environment:"
        echo "  FW_PORT  Default port (default: 3000)"
        ;;
    *)
        log_error "Unknown command: $cmd"
        echo "Usage: $(basename "$0") {start|stop|restart|status}" >&2
        exit 1
        ;;
esac
