#!/bin/bash
# mcp-reaper.sh — Detect and kill orphaned MCP processes
#
# When Claude Code sessions crash or end, MCP server processes (playwright-mcp,
# context7-mcp) become orphaned (PPID=1), accumulating ~50-270MB each.
#
# Detection: PPID=1 + MCP command pattern + age threshold + PGID leader dead
# Cleanup: SIGTERM -> 5s grace -> SIGKILL survivors
#
# Usage:
#   mcp-reaper.sh                    # Interactive: detect + confirm before killing
#   mcp-reaper.sh --dry-run          # Detect only, no killing
#   mcp-reaper.sh --force --quiet    # Automated: kill silently (for cron)
#   mcp-reaper.sh --age 60           # Set age threshold to 60 minutes
#
# Exit codes:
#   0 = no orphans found (or all reaped successfully)
#   1 = orphans found (dry-run) or reap failed/aborted
#   2 = usage error
#
# Research: docs/reports/experiment-zombie-mcp-orphan-reaper.md
# Part of: Agentic Engineering Framework (T-180)

set -euo pipefail

# Defaults
DRY_RUN=false
FORCE=false
AGE_THRESHOLD=30  # minutes
QUIET=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

show_help() {
    echo "MCP Orphan Reaper — Detect and kill orphaned MCP server processes"
    echo ""
    echo "Usage: mcp-reaper.sh [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Detect only, do not kill"
    echo "  --force      Kill without interactive confirmation"
    echo "  --quiet      Suppress normal output (errors still shown)"
    echo "  --age N      Age threshold in minutes (default: 30)"
    echo "  -h, --help   Show this help"
    echo ""
    echo "Examples:"
    echo "  mcp-reaper.sh                     # Interactive mode"
    echo "  mcp-reaper.sh --dry-run           # Detection only"
    echo "  mcp-reaper.sh --force --quiet     # For cron/automation"
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=true; shift ;;
        --force)    FORCE=true; shift ;;
        --age)      AGE_THRESHOLD="$2"; shift 2 ;;
        --quiet)    QUIET=true; shift ;;
        -h|--help)  show_help; exit 0 ;;
        *)          echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

log() { $QUIET || echo -e "$@"; }
warn() { echo -e "${YELLOW}WARNING:${NC} $*" >&2; }

# Detect orphaned MCP process groups
detect_orphans() {
    local age_seconds=$((AGE_THRESHOLD * 60))
    local -a orphan_pgids=()
    local -A pgid_info=()  # pgid -> "count|rss_mb"

    # Find MCP-related processes with PPID=1 (orphaned)
    # Pattern: npm exec + mcp-related packages, or node running mcp servers
    while IFS= read -r line; do
        local pid ppid pgid etimes rss args
        read -r pid ppid pgid etimes rss args <<< "$line"

        # Safety check 1: Must be orphaned (PPID=1)
        [[ "$ppid" -eq 1 ]] || continue

        # Safety check 2: Must be old enough
        [[ "$etimes" -ge "$age_seconds" ]] || continue

        # Safety check 3: No living claude process owns this PGID
        if ps -p "$pgid" -o comm= 2>/dev/null | grep -qi "claude"; then
            continue  # Active session — skip
        fi

        # Deduplicate by PGID
        local found=false
        for existing in "${orphan_pgids[@]+"${orphan_pgids[@]}"}"; do
            [[ "$existing" == "$pgid" ]] && found=true && break
        done
        $found || orphan_pgids+=("$pgid")

    done < <(ps -eo pid,ppid,pgid,etimes,rss,args 2>/dev/null | \
             grep -E "(npm exec.*(mcp|context7|playwright))|(node .*(mcp|context7))" | \
             grep -v grep || true)

    if [[ ${#orphan_pgids[@]} -eq 0 ]]; then
        log "${GREEN}No orphaned MCP process groups found.${NC}"
        return 0
    fi

    # Gather info per PGID
    local total_rss=0
    log "${BOLD}Found ${#orphan_pgids[@]} orphaned MCP process group(s):${NC}"
    log ""

    for pgid in "${orphan_pgids[@]}"; do
        local count rss_sum
        count=$(ps -eo pgid 2>/dev/null | awk -v g="$pgid" '$1 == g' | wc -l | tr -d ' ')
        rss_sum=$(ps -eo pgid,rss 2>/dev/null | awk -v g="$pgid" '$1 == g {sum+=$2} END {print sum+0}')
        local rss_mb=$((rss_sum / 1024))
        total_rss=$((total_rss + rss_sum))

        log "  ${BOLD}PGID $pgid:${NC} $count processes, ${rss_mb}MB RSS"

        if ! $QUIET; then
            # Show process details for this group
            ps -eo pid,ppid,pgid,etimes,rss,comm 2>/dev/null | \
                awk -v g="$pgid" 'NR==1 || $3 == g' | head -20 | sed 's/^/    /'
            echo ""
        fi
    done

    local total_mb=$((total_rss / 1024))
    log "${YELLOW}Total orphaned memory: ${total_mb}MB across ${#orphan_pgids[@]} group(s)${NC}"

    if $DRY_RUN; then
        log "(dry-run mode — no processes killed)"
        return 1  # Signal: orphans exist
    fi

    # Confirm before killing (unless --force)
    if ! $FORCE; then
        echo ""
        read -p "Kill these orphaned process groups? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy] ]] || { log "Aborted."; return 1; }
    fi

    # Reap: SIGTERM first
    for pgid in "${orphan_pgids[@]}"; do
        log "Sending SIGTERM to process group $pgid..."
        kill -TERM "-$pgid" 2>/dev/null || true
    done

    log "Waiting 5 seconds for graceful shutdown..."
    sleep 5

    # Check for survivors and SIGKILL
    local survivors=0
    for pgid in "${orphan_pgids[@]}"; do
        if ps -eo pgid 2>/dev/null | awk -v g="$pgid" '$1 == g' | grep -q .; then
            warn "PGID $pgid survived SIGTERM — sending SIGKILL"
            kill -KILL "-$pgid" 2>/dev/null || true
            survivors=$((survivors + 1))
        fi
    done

    if [[ $survivors -gt 0 ]]; then
        sleep 1
    fi

    log "${GREEN}Reap complete. Freed ~${total_mb}MB.${NC}"
    return 0
}

detect_orphans
