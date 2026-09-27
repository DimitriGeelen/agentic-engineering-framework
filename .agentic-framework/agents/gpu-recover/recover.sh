#!/bin/bash
# recover.sh — Free GPU memory by terminating the largest non-ollama VRAM consumer.
#
# Designed for shared GPU hosts where an ollama-using project hits a load
# failure because another project (FLUX, Whisper, ...) is holding VRAM.
# Reactive only — fires when invoked, not on a schedule.
#
# Usage:
#   fw gpu recover [--requester <name>] [--dry-run] [--threshold-mb N] [--json]
#
# Exit codes:
#   0 — action taken (process terminated) OR no action needed (no eligible target)
#   1 — error (nvidia-smi unavailable, parse failure)
#   2 — eligible target found but kill failed
#
# T-1182: Promoted from email-archive scripts/gpu-recover.sh per T-1180 GO.
# Origin: T-1181 implementation. Two-layer GPU coordination design.

set -uo pipefail

DRY_RUN=false
REQUESTER="unknown"
THRESHOLD_MB=2048
JSON_OUTPUT=false
LOG_FILE="${FW_GPU_RECOVER_LOG:-/var/log/fw-gpu-recover.log}"

while [ $# -gt 0 ]; do
    case "$1" in
        --requester) REQUESTER="${2:-unknown}"; shift 2 ;;
        --requester=*) REQUESTER="${1#--requester=}"; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --threshold-mb) THRESHOLD_MB="${2:-2048}"; shift 2 ;;
        --threshold-mb=*) THRESHOLD_MB="${1#--threshold-mb=}"; shift ;;
        --json) JSON_OUTPUT=true; shift ;;
        -h|--help)
            sed -n '2,16p' "$0"
            exit 0
            ;;
        *) shift ;;
    esac
done

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)

emit_log() {
    local msg="$1"
    if touch "$LOG_FILE" 2>/dev/null; then
        echo "${ts} requester=${REQUESTER} ${msg}" >> "$LOG_FILE"
    fi
}

emit_result() {
    local action="$1" pid="$2" mem_mb="$3" cmd="$4" reason="$5"
    if $JSON_OUTPUT; then
        printf '{"ts":"%s","requester":"%s","action":"%s","pid":"%s","mem_mb":"%s","cmd":"%s","reason":"%s"}\n' \
            "$ts" "$REQUESTER" "$action" "$pid" "$mem_mb" "$cmd" "$reason"
    else
        echo "[gpu-recover] action=${action} pid=${pid} mem_mb=${mem_mb} reason=${reason}"
    fi
    emit_log "action=${action} pid=${pid} mem_mb=${mem_mb} reason=${reason}"
}

if ! command -v nvidia-smi >/dev/null 2>&1; then
    emit_result "error" "" "" "" "nvidia-smi-not-available"
    exit 1
fi

apps_raw=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$apps_raw" ]; then
    emit_result "noop" "" "" "" "no-gpu-processes-detected"
    exit 0
fi

ollama_pids=$(pgrep -f 'ollama' 2>/dev/null | tr '\n' ',' | sed 's/,$//')

candidate_pid=""
candidate_mem=0
candidate_cmd=""

while IFS=',' read -r pid mem; do
    pid=$(echo "$pid" | tr -d ' ')
    mem=$(echo "$mem" | tr -d ' ')
    [ -z "$pid" ] && continue
    [ -z "$mem" ] && continue

    if [ -n "$ollama_pids" ]; then
        case ",${ollama_pids}," in
            *",${pid},"*) continue ;;
        esac
    fi

    if [ "$mem" -lt "$THRESHOLD_MB" ]; then
        continue
    fi

    if [ "$mem" -gt "$candidate_mem" ]; then
        candidate_pid="$pid"
        candidate_mem="$mem"
        candidate_cmd=$(ps -p "$pid" -o cmd= 2>/dev/null | head -c 200 | tr -d '\n,"')
    fi
done <<< "$apps_raw"

if [ -z "$candidate_pid" ]; then
    emit_result "noop" "" "" "" "no-eligible-target"
    exit 0
fi

if $DRY_RUN; then
    emit_result "would-kill" "$candidate_pid" "$candidate_mem" "$candidate_cmd" "dry-run"
    exit 0
fi

if ! kill -TERM "$candidate_pid" 2>/dev/null; then
    emit_result "error" "$candidate_pid" "$candidate_mem" "$candidate_cmd" "sigterm-failed"
    exit 2
fi

sleep 3

if kill -0 "$candidate_pid" 2>/dev/null; then
    if ! kill -KILL "$candidate_pid" 2>/dev/null; then
        emit_result "error" "$candidate_pid" "$candidate_mem" "$candidate_cmd" "sigkill-failed"
        exit 2
    fi
    emit_result "killed-9" "$candidate_pid" "$candidate_mem" "$candidate_cmd" "sigkill-after-sigterm"
else
    emit_result "killed-15" "$candidate_pid" "$candidate_mem" "$candidate_cmd" "sigterm-clean"
fi

exit 0
