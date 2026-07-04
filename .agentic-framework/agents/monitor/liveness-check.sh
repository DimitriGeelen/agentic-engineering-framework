#!/bin/bash
# liveness-check.sh — TermLink hub + framework agent + Claude instance + Watchtower liveness
# T-1269/T-1273: runs every 1 minute via cron and on @reboot
# Outputs: .context/monitors/liveness.jsonl (append-only), liveness-latest.yaml (snapshot)

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/opt/999-Agentic-Engineering-Framework}"
MONITOR_DIR="$PROJECT_ROOT/.context/monitors"
LOG_FILE="$MONITOR_DIR/liveness.jsonl"
LATEST_FILE="$MONITOR_DIR/liveness-latest.yaml"
RETENTION_LINES=10080

mkdir -p "$MONITOR_DIR"

timestamp=$(date -Iseconds)
hostname=$(hostname)
boot_marker="${LIVENESS_BOOT_MARKER:-0}"

hub_state="unavailable"
hub_detail=""
if command -v termlink >/dev/null 2>&1; then
    hub_out=$(termlink hub status 2>&1 || true)
    if echo "$hub_out" | grep -qiE "^Hub: running|status: ready|is running"; then
        hub_state="running"
    elif echo "$hub_out" | grep -qiE "stale|dead"; then
        hub_state="stale"
        hub_detail="needs cleanup"
    elif echo "$hub_out" | grep -qiE "not running|stopped|no hub"; then
        hub_state="stopped"
    else
        hub_state="unknown"
        hub_detail="$(echo "$hub_out" | head -1 | tr -d '"' | cut -c1-80)"
    fi
fi

claude_count=$(pgrep -fc "claude-desktop|/claude[[:space:]]|claude-fw|claude-code" 2>/dev/null | head -1 || true)
claude_count=${claude_count:-0}
claude_count=$((claude_count + 0))

fw_agent_session="none"
fw_agent_id=""
if command -v termlink >/dev/null 2>&1; then
    agent_line=$(termlink list 2>/dev/null | grep -iE "agent|pickup" | grep -ivE "upg|upgrade|rec[0-9]" | head -1 || true)
    if [ -n "$agent_line" ]; then
        fw_agent_id=$(echo "$agent_line" | awk '{print $1}')
        fw_agent_session=$(echo "$agent_line" | awk '{print $3}')
    fi
fi

watchtower_state="stopped"
# Read Watchtower URL from triple-file source-of-truth (T-1287); fall back to fw_config PORT,
# then default 3000. Never hard-code :3000 — consumer projects configure FW_PORT per-project (T-885).
wt_url=$(cat "$PROJECT_ROOT/.context/working/watchtower.url" 2>/dev/null || true)
if [ -z "$wt_url" ]; then
    wt_port=""
    if [ -f "$PROJECT_ROOT/lib/config.sh" ]; then
        # shellcheck disable=SC1091
        . "$PROJECT_ROOT/lib/config.sh" 2>/dev/null || true
        wt_port=$(fw_config "PORT" "" 2>/dev/null || echo "")
    fi
    wt_url="http://localhost:${wt_port:-3000}"
fi
if curl -sf -m 2 "${wt_url%/}/" >/dev/null 2>&1; then
    watchtower_state="running"
fi

# ── Watchtower watchdog (T-100140) ──────────────────────────────────────────
# 2026-07-04 outage: the server hung (135-thread GIL livelock) while this
# monitor dutifully logged `watchtower: stopped` every minute for 3+ hours —
# detection without remediation. Self-heal rule: the pid file exists (the
# instance is SUPPOSED to be running — a deliberate `watchtower.sh stop`
# removes it) AND the HTTP probe has failed WATCHDOG_THRESHOLD consecutive
# runs → restart via bin/watchtower.sh restart (which preserves the port).
# The counter resets on success and after each restart attempt, so restarts
# are spaced at least THRESHOLD minutes apart (no tight restart loop while a
# cold cache rebuilds). Opt out: WATCHTOWER_WATCHDOG=0.
WATCHDOG_ENABLED="${WATCHTOWER_WATCHDOG:-1}"
WATCHDOG_THRESHOLD="${WATCHTOWER_WATCHDOG_THRESHOLD:-3}"
WATCHDOG_STATE="$MONITOR_DIR/.watchtower-probe-failures"
wt_pid_file="$PROJECT_ROOT/.context/working/watchtower.pid"
if [ "$watchtower_state" = "running" ]; then
    rm -f "$WATCHDOG_STATE"
elif [ "$WATCHDOG_ENABLED" = "1" ] && [ -f "$wt_pid_file" ]; then
    fails=$(( $(cat "$WATCHDOG_STATE" 2>/dev/null || echo 0) + 1 ))
    echo "$fails" > "$WATCHDOG_STATE"
    if [ "$fails" -ge "$WATCHDOG_THRESHOLD" ]; then
        restart_out=$("$PROJECT_ROOT/bin/watchtower.sh" restart 2>&1 | tail -3 | tr '\n' ' ' | tr -d '"\\' || true)
        printf '{"ts":"%s","host":"%s","event":"watchtower-watchdog-restart","consecutive_failures":%d,"detail":"%s"}\n' \
            "$timestamp" "$hostname" "$fails" "$restart_out" >> "$LOG_FILE"
        rm -f "$WATCHDOG_STATE"
    fi
fi

printf '{"ts":"%s","host":"%s","boot":%s,"termlink_hub":"%s","termlink_hub_detail":"%s","claude_instances":%d,"fw_agent_session":"%s","fw_agent_id":"%s","watchtower":"%s"}\n' \
    "$timestamp" "$hostname" "$boot_marker" "$hub_state" "$hub_detail" "$claude_count" "$fw_agent_session" "$fw_agent_id" "$watchtower_state" \
    >> "$LOG_FILE"

cat > "$LATEST_FILE" <<EOF
# Liveness snapshot (T-1269, T-1273)
timestamp: $timestamp
host: $hostname
boot_marker: $boot_marker
termlink:
  hub: $hub_state
  detail: "$hub_detail"
claude_instances: $claude_count
framework_agent:
  session: $fw_agent_session
  id: "$fw_agent_id"
watchtower: $watchtower_state
EOF

if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$RETENTION_LINES" ]; then
    tail -"$RETENTION_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
