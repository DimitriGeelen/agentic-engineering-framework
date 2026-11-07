#!/usr/bin/env bash
# T-5061 (G-130): name runaway files under .context/working/ before they fill a disk.
#
# Origin: on the Greenfield laptop .context/working/.checkpoint.handover.stderr reached 183 GB
# of one repeated handover block in under two hours; the host disk filled, WSL and the
# operator's Claude crashed, and nothing had warned. fw doctor and fw audit both call this.
#
# Database files (*.db and their -wal/-shm journals, e.g. the semantic index) are large by
# design and are skipped. Threshold: FW_WORKING_FILE_WARN_BYTES (default 1 GiB).
#
# Usage: source it, then  fw_working_oversized <working-dir> [threshold-bytes]
# Prints "<bytes> <path relative to working-dir>" per oversized file, largest first.
# Exit 0 always; no output means none.

fw_working_oversized() {
    local dir="${1:-}" limit="${2:-${FW_WORKING_FILE_WARN_BYTES:-1073741824}}"
    [ -n "$dir" ] && [ -d "$dir" ] || return 0
    case "$limit" in ''|*[!0-9]*) limit=1073741824 ;; esac
    find "$dir" -xdev -type f -size +"${limit}"c \
        ! -name '*.db' ! -name '*.db-wal' ! -name '*.db-shm' \
        -printf '%s %P\n' 2>/dev/null | sort -rn
    return 0
}

# Human-readable size for a byte count (1.5G, 300M, 12K).
fw_working_human_size() {
    awk -v b="${1:-0}" 'BEGIN { split("B K M G T", u, " "); i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        printf (i == 1 ? "%d%s" : "%.1f%s"), b, u[i] }'
}
