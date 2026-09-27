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
    if [ -f "${FRAMEWORK_ROOT:-$PROJECT_ROOT}/lib/config.sh" ]; then
        # shellcheck disable=SC1091
        . "${FRAMEWORK_ROOT:-$PROJECT_ROOT}/lib/config.sh" 2>/dev/null || true
        wt_port=$(fw_config "PORT" "" 2>/dev/null || echo "")
    fi
    wt_url="http://localhost:${wt_port:-3000}"
fi
# OBS-437 / T-3382: probe /api/_identity and require project_root to match OURS.
# The previous probe was `curl -sf -m 2 "$wt_url/"` — the heaviest page in the
# app under a 2-second budget. Measured 2026-09-17 with the server confirmed
# up: the root page took 4.47s and 2.37s on consecutive hits, curl exited 28,
# and this rail wrote `stopped` — a FALSE NEGATIVE it had been emitting since
# ~2026-06-12, two months before the exec-bit death (T-3380) silenced it
# entirely. /api/_identity answers in ~1ms and, unlike `/`, says WHOSE server
# answered: on this host :3000 belongs to another project (T-1376/T-2732), and
# a bare 200 from the wrong Watchtower is the false-green class. Raising the
# timeout alone would have traded a false negative for a slow check that still
# could not tell the servers apart. The identity handshake lives in one place
# (lib/watchtower.sh:_watchtower_identity_matches, T-1803/T-3054); it is
# sourced, not copied, so this rail cannot drift from fw doctor's answer.
#
# Three states, not two: `foreign` means something answered on our URL that is
# not our Watchtower. Under the old probe that read as `running`.
_wt_lib="${FRAMEWORK_ROOT:-$PROJECT_ROOT}/lib/watchtower.sh"
if [ -f "$_wt_lib" ]; then
    export FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$PROJECT_ROOT}" PROJECT_ROOT
    set +u
    # shellcheck disable=SC1090
    . "$_wt_lib" 2>/dev/null || true
    set -u
fi
if command -v _watchtower_identity_matches >/dev/null 2>&1 \
   && _watchtower_identity_matches "${wt_url%/}" 2>/dev/null; then
    watchtower_state="running"
else
    # Not ours (or helper unavailable): is ANYTHING answering there? curl
    # prints 000 itself on a connection failure — do NOT `|| echo 000` after
    # it, that yields "000000" and reads as foreign (caught by test 4).
    _wt_code=$(curl -s -o /dev/null -w '%{http_code}' -m 5 "${wt_url%/}/api/_identity" 2>/dev/null) || true
    if [ "${_wt_code:-000}" != "000" ]; then
        watchtower_state="foreign"
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
