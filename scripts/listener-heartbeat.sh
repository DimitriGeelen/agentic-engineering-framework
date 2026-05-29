#!/usr/bin/env bash
# T-1832 — listener-heartbeat emitter (T-1830 sub-build a).
#
# Establishes the agent-presence convention for the doorbell+mail
# adoption push. Without presence signals there's nothing for the
# discovery verb (T-1833) to read. Each listener posts a heartbeat
# every --interval seconds declaring its agent_id, role, and the
# topics it's actively listening on.
#
# Convention (T-1830 GO):
#   - Topic:       agent-presence (per-hub; channels are hub-local — G-060)
#   - msg_type:    heartbeat
#   - payload:     role string (free-form, e.g. "listener", "responder")
#   - metadata:
#       agent_id:      <name>     (required)
#       role:          <role>     (default "listener")
#       listen_topics: <csv>      (comma-joined --listen-topic args; "" if none)
#       started_at:    <RFC3339>  (process boot ts — fixed across loop iterations)
#       interval_secs: <N>        (heartbeat period — consumer uses for staleness math)
#       host:          <hostname> (informational; not identity — payload labels are not identity, see reference_shared_host_identity.md)
#
# Consumer TTL convention (informational; not enforced server-side):
#   - heartbeat newer than 2*interval  = LIVE
#   - heartbeat between 2*interval and 5*interval = STALE
#   - heartbeat older than 5*interval  = OFFLINE
#
# Exit codes:
#   0  — normal exit (clean signal received OR --once success)
#   2  — usage error (missing required flag, unknown arg)
#   3  — hub-side error (post failed)
set -u

TERMLINK="${TERMLINK_BIN:-termlink}"

die_usage() {
    echo "listener-heartbeat: $*" >&2
    echo "Try --help for usage." >&2
    exit 2
}

usage() {
    cat <<'EOF'
Usage: listener-heartbeat.sh --agent-id NAME [OPTIONS]

Post agent-presence heartbeats so peers can discover this listener
(T-1830 sub-build a). Default: loop, posting every 30 seconds, until
SIGINT/SIGTERM. --once for a single post-and-exit cycle.

Required:
  --agent-id NAME      Logical agent name (e.g. "cohort-agent", "claude-code-A")

Optional:
  --role R             Role string (default: "listener"). Also used as payload.
  --listen-topic T     Topic this agent is listening on. Repeatable. Joined into
                       metadata.listen_topics as comma-separated.
  --pty-session NAME   PTY session name to ring for doorbell (T-1834). When
                       declared, surfaces in metadata.pty_session so
                       agent-send.sh --to AGENT_ID can auto-discover the
                       doorbell target. Omit if no PTY session is bound.
  --topic TOPIC        Heartbeat topic (default: agent-presence)
  --interval N         Heartbeat period in seconds (default: 30; min: 5)
  --hub addr           Target hub (default: local)
  --once               Post exactly one heartbeat and exit 0.
  --json               On --once, emit the channel-post JSON envelope on stdout.
                       On loop mode, emit one JSON line per heartbeat.
  -h, --help           Print this help and exit 0.

Exit codes:
  0  normal exit / --once success
  2  usage error
  3  hub-side error (post failed)

Convention:
  Topic auto-created on first post via channel.post --ensure-topic.
  Each envelope carries: msg_type=heartbeat, metadata.{agent_id, role,
  listen_topics, started_at, interval_secs, host}.
EOF
}

agent_id=""
role="listener"
listen_topics=()
pty_session=""
topic="agent-presence"
interval=30
hub=""
once=0
json=0

while [ $# -gt 0 ]; do
    case "$1" in
        --agent-id)      agent_id="${2:-}"; shift 2 ;;
        --role)          role="${2:-}"; shift 2 ;;
        --listen-topic)  listen_topics+=("${2:-}"); shift 2 ;;
        --pty-session)   pty_session="${2:-}"; shift 2 ;;
        --topic)         topic="${2:-}"; shift 2 ;;
        --interval)      interval="${2:-}"; shift 2 ;;
        --hub)           hub="${2:-}"; shift 2 ;;
        --once)          once=1; shift ;;
        --json)          json=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        *)               die_usage "unknown arg: $1" ;;
    esac
done

[ -n "$agent_id" ] || die_usage "missing required --agent-id"
[ -n "$role" ] || die_usage "--role must not be empty"
[ -n "$topic" ] || die_usage "--topic must not be empty"

# Numeric guard on --interval: must be positive int >= 5.
case "$interval" in
    ''|*[!0-9]*) die_usage "--interval must be a positive integer (got: $interval)" ;;
esac
[ "$interval" -ge 5 ] || die_usage "--interval must be >= 5 seconds (got: $interval)"

# Comma-join listen_topics (empty string if none).
listen_csv=""
if [ "${#listen_topics[@]}" -gt 0 ]; then
    listen_csv="$(printf '%s,' "${listen_topics[@]}")"
    listen_csv="${listen_csv%,}"
fi

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo unknown)"

hub_args=()
[ -n "$hub" ] && hub_args+=(--hub "$hub")

post_one() {
    local post_args=(channel post "${hub_args[@]}" "$topic" \
        --ensure-topic \
        --msg-type heartbeat \
        --payload "$role" \
        --metadata "agent_id=$agent_id" \
        --metadata "role=$role" \
        --metadata "listen_topics=$listen_csv" \
        --metadata "started_at=$started_at" \
        --metadata "interval_secs=$interval" \
        --metadata "host=$host")
    # T-1834: declare pty_session only when provided. Empty string would
    # confuse auto-discover (it would consider an empty value valid).
    [ -n "$pty_session" ] && post_args+=(--metadata "pty_session=$pty_session")
    post_args+=(--json)
    "$TERMLINK" "${post_args[@]}" 2>&1
}

emit_once() {
    local out rc
    out="$(post_one)"
    rc=$?
    if [ "$rc" -ne 0 ]; then
        echo "listener-heartbeat: post failed (exit=$rc): $out" >&2
        return 3
    fi
    if [ "$json" -eq 1 ]; then
        printf '%s\n' "$out"
    fi
    return 0
}

# Loop mode — graceful SIGINT/SIGTERM.
keep_running=1
on_signal() { keep_running=0; }
trap on_signal INT TERM

if [ "$once" -eq 1 ]; then
    emit_once
    exit $?
fi

while [ "$keep_running" -eq 1 ]; do
    emit_once || exit 3
    # Sleep in 1-sec chunks so signals are responsive.
    n="$interval"
    while [ "$n" -gt 0 ] && [ "$keep_running" -eq 1 ]; do
        sleep 1
        n=$((n - 1))
    done
done

exit 0
