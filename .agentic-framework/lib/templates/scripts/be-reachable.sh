#!/usr/bin/env bash
# T-1841 — be-reachable wrapper for ephemeral claude-code sessions.
#
# One-command opt-in to agent-presence (T-1830). Backgrounds
# listener-heartbeat.sh (T-1832), persists PID + agent_id in
# ~/.termlink/be-reachable.state, applies sensible defaults so a
# claude-code session becomes reachable via T-1834 --to auto-discover
# in under 30 seconds.
#
# Mirrors the persistent-host rail (T-1840 systemd template) but for
# session-lifetime instances that should die with the terminal.
#
# Subcommands:
#   start [--agent-id X] [--pty-session Y] [--listen-topic T]... [--role R]
#         [--interval N] [--hub addr] [--topic AGENT-PRESENCE]
#   stop
#   status [--json]
#
# State file: ~/.termlink/be-reachable.state (or $BE_REACHABLE_STATE)
#   JSON: { agent_id, pid, started_at, role, interval, topic,
#           listen_topics: [...], pty_session, hub }
#
# Exit codes:
#   0  — success (incl. idempotent already-running / not-running)
#   1  — status reports not-running (status only)
#   2  — usage error
#   3  — hub-side / spawn failure
set -u

TERMLINK="${TERMLINK_BIN:-termlink}"
STATE_DIR="${BE_REACHABLE_STATE_DIR:-${HOME}/.termlink}"
STATE_FILE="${BE_REACHABLE_STATE:-${STATE_DIR}/be-reachable.state}"

LH_SCRIPT="${BE_REACHABLE_LH_SCRIPT:-}"
if [ -z "$LH_SCRIPT" ]; then
    # Resolve listener-heartbeat.sh relative to this script's directory by default.
    SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
    LH_SCRIPT="${SELF_DIR}/listener-heartbeat.sh"
fi

usage() {
    cat <<'EOF'
Usage: be-reachable.sh <subcommand> [options]

Subcommands:
  start    Background a listener-heartbeat process for this session.
  stop     Kill the background process and clear state.
  status   Report running state. Exit 0=running, 1=not running.
  --help   Print this help and exit 0.

start options:
  --agent-id NAME      Logical agent name (default: $USER-claude-$(hostname -s))
  --pty-session NAME   PTY session name for doorbell ring (default: auto-detect
                       from $TMUX or $STY; empty if none)
  --listen-topic T     Topic to declare in metadata. Repeatable.
                       Default: dm:<agent_id>:* and agent-chat-arc.
  --role R             Role string (default: claude-code)
  --interval N         Heartbeat period seconds (default: 30, min: 5)
  --hub addr           Target hub (default: local)
  --topic TOPIC        Presence topic (default: agent-presence)

status options:
  --json               Emit JSON instead of human-readable text.

Environment:
  BE_REACHABLE_STATE       Override state file path
  BE_REACHABLE_LH_SCRIPT   Override listener-heartbeat.sh path
  TERMLINK_BIN             Override termlink binary

Examples:
  be-reachable.sh start                       # default agent_id, default topics
  be-reachable.sh start --agent-id me         # custom name
  be-reachable.sh status --json
  be-reachable.sh stop

After `start`, peers can reach you via:
  termlink agent contact <agent_id> --message "[T-XXX] ..."
  bash scripts/agent-send.sh --to <agent_id> --message "..."
EOF
}

die_usage() {
    echo "be-reachable: $*" >&2
    echo "Try --help for usage." >&2
    exit 2
}

# ---- state file helpers --------------------------------------------------

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
    chmod 700 "$STATE_DIR" 2>/dev/null || true
}

read_state_field() {
    # $1 = field name. Prints value to stdout, empty if missing.
    [ -f "$STATE_FILE" ] || return 0
    if command -v jq >/dev/null 2>&1; then
        jq -r ".${1} // empty" "$STATE_FILE" 2>/dev/null
    else
        # Fallback: naive grep for "field": "value" or "field": <int>
        sed -n "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" "$STATE_FILE" | head -n1
    fi
}

pid_alive() {
    local pid="$1"
    [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null && kill -0 "$pid" 2>/dev/null
}

# ---- defaults ------------------------------------------------------------

default_agent_id() {
    local u h
    u="${USER:-$(id -un 2>/dev/null || echo agent)}"
    h="$(hostname -s 2>/dev/null || echo host)"
    # Normalize: lowercase, replace non-alnum with -
    printf '%s' "${u}-claude-${h}" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9-' '-' | sed 's/--*/-/g; s/^-//; s/-$//'
}

default_pty_session() {
    # tmux: $TMUX is "/tmp/tmux-1000/default,12345,0" → grab session via tmux display-message if available
    if [ -n "${TMUX:-}" ]; then
        if command -v tmux >/dev/null 2>&1; then
            tmux display-message -p '#S' 2>/dev/null || echo ""
        else
            # Fall back to client name parsed from $TMUX
            printf '%s' "$TMUX" | awk -F, '{print $1}' | xargs -I{} basename {} 2>/dev/null || echo ""
        fi
        return
    fi
    if [ -n "${STY:-}" ]; then
        # screen: STY is "PID.session"
        printf '%s' "$STY" | sed 's/^[0-9]*\.//'
        return
    fi
    echo ""
}

# ---- subcommands ---------------------------------------------------------

cmd_start() {
    local agent_id=""
    local pty_session=""
    local pty_session_set=0
    local listen_topics=()
    local role="claude-code"
    local interval=30
    local hub=""
    local topic="agent-presence"

    while [ $# -gt 0 ]; do
        case "$1" in
            --agent-id)      agent_id="${2:-}"; shift 2 ;;
            --pty-session)   pty_session="${2:-}"; pty_session_set=1; shift 2 ;;
            --listen-topic)  listen_topics+=("${2:-}"); shift 2 ;;
            --role)          role="${2:-}"; shift 2 ;;
            --interval)      interval="${2:-}"; shift 2 ;;
            --hub)           hub="${2:-}"; shift 2 ;;
            --topic)         topic="${2:-}"; shift 2 ;;
            -h|--help)       usage; exit 0 ;;
            *)               die_usage "unknown start arg: $1" ;;
        esac
    done

    # Pre-flight: listener-heartbeat.sh must exist & be executable.
    if [ ! -x "$LH_SCRIPT" ]; then
        echo "be-reachable: listener-heartbeat.sh not found or not executable: $LH_SCRIPT" >&2
        echo "Set BE_REACHABLE_LH_SCRIPT to override." >&2
        exit 3
    fi

    ensure_state_dir

    # Idempotent: existing PID alive?
    if [ -f "$STATE_FILE" ]; then
        local existing_pid existing_id
        existing_pid="$(read_state_field pid)"
        existing_id="$(read_state_field agent_id)"
        if pid_alive "$existing_pid"; then
            echo "be-reachable: already running as ${existing_id:-?} (pid ${existing_pid})"
            echo "  state: ${STATE_FILE}"
            echo "  stop first if you want to change agent_id or topics."
            exit 0
        fi
        # Stale state: PID dead, clear it.
        rm -f "$STATE_FILE"
    fi

    # Apply defaults.
    [ -n "$agent_id" ] || agent_id="$(default_agent_id)"
    if [ "$pty_session_set" -eq 0 ]; then
        pty_session="$(default_pty_session)"
    fi
    if [ "${#listen_topics[@]}" -eq 0 ]; then
        listen_topics=("dm:${agent_id}:*" "agent-chat-arc")
    fi

    # Build listener-heartbeat.sh args.
    local lh_args=( --agent-id "$agent_id" --role "$role" --topic "$topic" --interval "$interval" )
    [ -n "$pty_session" ] && lh_args+=( --pty-session "$pty_session" )
    [ -n "$hub" ] && lh_args+=( --hub "$hub" )
    local t
    for t in "${listen_topics[@]}"; do
        [ -n "$t" ] && lh_args+=( --listen-topic "$t" )
    done

    # Spawn detached. nohup + setsid so it survives this shell exit.
    # Stdout/stderr → state log alongside the state file.
    local log_file="${STATE_DIR}/be-reachable.log"
    : > "$log_file"

    if command -v setsid >/dev/null 2>&1; then
        nohup setsid "$LH_SCRIPT" "${lh_args[@]}" >>"$log_file" 2>&1 &
    else
        nohup "$LH_SCRIPT" "${lh_args[@]}" >>"$log_file" 2>&1 &
    fi
    local pid=$!
    disown 2>/dev/null || true

    # Brief settle so we can detect immediate-exit failures.
    sleep 1
    if ! pid_alive "$pid"; then
        echo "be-reachable: listener-heartbeat.sh exited immediately. log: ${log_file}" >&2
        tail -n 20 "$log_file" >&2 || true
        exit 3
    fi

    # Write state file.
    local started_at
    started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    # Build the listen_topics JSON array manually (jq optional in environment).
    local lt_json="["
    local first=1
    for t in "${listen_topics[@]}"; do
        if [ -z "$t" ]; then continue; fi
        if [ $first -eq 1 ]; then
            lt_json+="\"$t\""
            first=0
        else
            lt_json+=",\"$t\""
        fi
    done
    lt_json+="]"

    cat >"$STATE_FILE" <<EOF
{
  "agent_id": "${agent_id}",
  "pid": ${pid},
  "started_at": "${started_at}",
  "role": "${role}",
  "interval": ${interval},
  "topic": "${topic}",
  "listen_topics": ${lt_json},
  "pty_session": "${pty_session}",
  "hub": "${hub}"
}
EOF
    chmod 600 "$STATE_FILE" 2>/dev/null || true

    cat <<EOF
be-reachable: started.
  agent_id:      ${agent_id}
  pid:           ${pid}
  pty_session:   ${pty_session:-<none>}
  listen_topics: $(IFS=,; echo "${listen_topics[*]}")
  state:         ${STATE_FILE}
  log:           ${log_file}

Peers can reach you via:
  termlink agent contact ${agent_id} --message "[T-XXX] ..."
  bash scripts/agent-send.sh --to ${agent_id} --message "..."

Stop with: be-reachable.sh stop
EOF
}

cmd_stop() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "be-reachable: not running (no state file)."
        exit 0
    fi
    local pid agent_id
    pid="$(read_state_field pid)"
    agent_id="$(read_state_field agent_id)"

    if pid_alive "$pid"; then
        kill -TERM "$pid" 2>/dev/null || true
        # Graceful wait up to 3s.
        local i
        for i in 1 2 3; do
            sleep 1
            pid_alive "$pid" || break
        done
        if pid_alive "$pid"; then
            kill -KILL "$pid" 2>/dev/null || true
            sleep 1
        fi
        echo "be-reachable: stopped ${agent_id:-?} (pid ${pid})."
    else
        echo "be-reachable: state existed but pid ${pid:-?} was already gone; clearing."
    fi
    rm -f "$STATE_FILE"
    exit 0
}

cmd_status() {
    local json=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --json)    json=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *)         die_usage "unknown status arg: $1" ;;
        esac
    done

    if [ ! -f "$STATE_FILE" ]; then
        if [ "$json" -eq 1 ]; then
            echo '{"running": false, "reason": "no state file"}'
        else
            echo "be-reachable: not running."
        fi
        exit 1
    fi

    local pid agent_id started_at role interval pty_session
    pid="$(read_state_field pid)"
    agent_id="$(read_state_field agent_id)"
    started_at="$(read_state_field started_at)"
    role="$(read_state_field role)"
    interval="$(read_state_field interval)"
    pty_session="$(read_state_field pty_session)"

    if pid_alive "$pid"; then
        if [ "$json" -eq 1 ]; then
            # Decorate the existing state file with running=true.
            if command -v jq >/dev/null 2>&1; then
                jq '. + {running: true}' "$STATE_FILE"
            else
                # Append before closing brace.
                sed 's/}[[:space:]]*$/, "running": true}/' "$STATE_FILE"
            fi
        else
            cat <<EOF
be-reachable: running.
  agent_id:    ${agent_id:-?}
  pid:         ${pid}
  started_at:  ${started_at:-?}
  role:        ${role:-?}
  interval:    ${interval:-?}
  pty_session: ${pty_session:-<none>}
  state:       ${STATE_FILE}
EOF
        fi
        exit 0
    else
        if [ "$json" -eq 1 ]; then
            echo "{\"running\": false, \"reason\": \"stale state\", \"pid\": ${pid:-null}, \"agent_id\": \"${agent_id:-}\"}"
        else
            echo "be-reachable: not running (stale state — pid ${pid:-?} gone). Run 'be-reachable.sh stop' to clear."
        fi
        exit 1
    fi
}

# ---- dispatch ------------------------------------------------------------

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

case "$1" in
    start)     shift; cmd_start "$@" ;;
    stop)     shift; cmd_stop "$@" ;;
    status)   shift; cmd_status "$@" ;;
    -h|--help) usage; exit 0 ;;
    *)        die_usage "unknown subcommand: $1" ;;
esac
