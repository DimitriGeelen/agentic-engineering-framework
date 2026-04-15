#!/bin/bash
# liveness-check.sh — TermLink hub + Claude instance + Watchtower liveness
# T-1269: runs every 1 minute via cron and on @reboot
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

watchtower_state="stopped"
if curl -sf -m 2 http://localhost:3000/ >/dev/null 2>&1; then
    watchtower_state="running"
fi

printf '{"ts":"%s","host":"%s","boot":%s,"termlink_hub":"%s","termlink_hub_detail":"%s","claude_instances":%d,"watchtower":"%s"}\n' \
    "$timestamp" "$hostname" "$boot_marker" "$hub_state" "$hub_detail" "$claude_count" "$watchtower_state" \
    >> "$LOG_FILE"

cat > "$LATEST_FILE" <<EOF
# Liveness snapshot (T-1269)
timestamp: $timestamp
host: $hostname
boot_marker: $boot_marker
termlink:
  hub: $hub_state
  detail: "$hub_detail"
claude_instances: $claude_count
watchtower: $watchtower_state
EOF

if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt "$RETENTION_LINES" ]; then
    tail -"$RETENTION_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
