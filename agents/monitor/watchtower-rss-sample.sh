#!/bin/bash
# watchtower-rss-sample.sh — periodic RSS/CPU sample of the Watchtower process
# T-1615 (T-1611-B): every 5 min via cron. Used to distinguish memory-leak
# re-saturation from request-rate queueing. If RSS climbs monotonically over
# many hours, T-1612's threaded=True fix is incomplete and T-1611-C (gunicorn
# swap) reopens. If RSS stays bounded, the cheap fix is sufficient.
#
# Outputs:
#   .context/monitors/watchtower-rss.jsonl       — append-only history
#   .context/monitors/watchtower-rss-latest.yaml — most recent sample
#
# Pattern matches agents/monitor/liveness-check.sh (T-1269/T-1273).

set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-/opt/999-Agentic-Engineering-Framework}"
MONITOR_DIR="$PROJECT_ROOT/.context/monitors"
LOG_FILE="$MONITOR_DIR/watchtower-rss.jsonl"
LATEST_FILE="$MONITOR_DIR/watchtower-rss-latest.yaml"
PID_FILE="$PROJECT_ROOT/.context/working/watchtower.pid"
RETENTION_LINES=10080

mkdir -p "$MONITOR_DIR"

timestamp=$(date -Iseconds)
hostname_=$(hostname)

# Resolve PID via triple-file source-of-truth (T-1376). Falls back to "down"
# if file missing or process not alive.
state="down"
pid=""
etime_sec=""
rss_kb=""
vsz_kb=""
pcpu=""
detail=""

if [ -f "$PID_FILE" ]; then
    pid=$(tr -d '[:space:]' < "$PID_FILE" 2>/dev/null || echo "")
fi

if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    # ps -o etime returns [[DD-]HH:]MM:SS — convert to total seconds.
    # rss/vsz are in KB on Linux. pcpu is the running average since process start.
    line=$(ps -p "$pid" -o etime=,rss=,vsz=,pcpu= 2>/dev/null | awk '{$1=$1; print}' || echo "")
    if [ -n "$line" ]; then
        etime_raw=$(echo "$line" | awk '{print $1}')
        rss_kb=$(echo "$line" | awk '{print $2}')
        vsz_kb=$(echo "$line" | awk '{print $3}')
        pcpu=$(echo "$line" | awk '{print $4}')

        # Convert etime to seconds. Format options:
        #   SS, MM:SS, HH:MM:SS, DD-HH:MM:SS
        days=0
        rest="$etime_raw"
        case "$rest" in
            *-*) days="${rest%%-*}"; rest="${rest#*-}" ;;
        esac
        # Now rest is HH:MM:SS or MM:SS or SS
        h=0; m=0; s=0
        ifs_save=$IFS
        IFS=':'
        # shellcheck disable=SC2206  # word-splitting on : is intentional
        parts=( $rest )
        IFS=$ifs_save
        case ${#parts[@]} in
            3) h=${parts[0]}; m=${parts[1]}; s=${parts[2]} ;;
            2) m=${parts[0]}; s=${parts[1]} ;;
            1) s=${parts[0]} ;;
        esac
        # Strip leading zeros to avoid octal interpretation
        days=$((10#${days:-0}))
        h=$((10#${h:-0}))
        m=$((10#${m:-0}))
        s=$((10#${s:-0}))
        etime_sec=$(( days*86400 + h*3600 + m*60 + s ))
        state="up"
    else
        detail="ps query failed"
    fi
else
    detail="pid file missing or process dead"
fi

# Emit JSONL line. Quote-safe: only emit numeric fields when state=up.
if [ "$state" = "up" ]; then
    printf '{"timestamp":"%s","host":"%s","pid":%s,"etime_sec":%s,"rss_kb":%s,"vsz_kb":%s,"pcpu":%s,"state":"up"}\n' \
        "$timestamp" "$hostname_" "$pid" "$etime_sec" "$rss_kb" "$vsz_kb" "$pcpu" >> "$LOG_FILE"
else
    printf '{"timestamp":"%s","host":"%s","state":"down","detail":"%s"}\n' \
        "$timestamp" "$hostname_" "$detail" >> "$LOG_FILE"
fi

# Retention: keep last N lines.
if [ -f "$LOG_FILE" ]; then
    line_count=$(wc -l < "$LOG_FILE")
    if [ "$line_count" -gt "$RETENTION_LINES" ]; then
        tail -n "$RETENTION_LINES" "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

# Latest snapshot in YAML.
{
    echo "timestamp: $timestamp"
    echo "host: $hostname_"
    echo "state: $state"
    if [ "$state" = "up" ]; then
        echo "pid: $pid"
        echo "etime_sec: $etime_sec"
        echo "rss_kb: $rss_kb"
        echo "vsz_kb: $vsz_kb"
        echo "pcpu: $pcpu"
    else
        echo "detail: \"$detail\""
    fi
} > "$LATEST_FILE"
