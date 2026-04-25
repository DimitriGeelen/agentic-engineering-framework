#!/bin/bash
# Pre-Compaction Hook — Save structured context before lossy compaction
# Fires on PreCompact — manual /compact only (auto-compaction disabled per D-027).
#
# Generates a handover so that SessionStart:compact can
# reinject structured context into the fresh session.
#
# Part of: T-111 (Autonomous compact-resume lifecycle)
# Updated: T-175 (D-028 — single handover, no emergency distinction)
# Updated: T-177 (manual-only cleanup, D-027 documentation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"

# T-1476/T-1478: Dual-layer dedup against duplicate PreCompact hook fires.
# When both user-level (~/.claude/settings.json) and project-level
# (.claude/settings.json) register this hook, /compact triggers two
# invocations. They fire close enough that the commit-message dedup races,
# but they may fire SEQUENTIALLY (run A finishes before B starts) — flock
# alone doesn't catch that case. So:
#   1. flock — catches truly parallel fires (race window)
#   2. time-window check — catches sequential fires within DEDUP_WINDOW
# T-1476's original trap-rm of the lockfile turned out to be the bug: A's
# trap removed the lockfile on exit, so B's exec opened a fresh inode and
# B's flock granted on a different lock. Leaving the lockfile in place is
# harmless: it stays empty, never grows, and lets flock enforce mutual
# exclusion across runs that share the same inode.
PRE_COMPACT_LOCK_DIR="$PROJECT_ROOT/.context/working"
mkdir -p "$PRE_COMPACT_LOCK_DIR" 2>/dev/null
PRE_COMPACT_LOCK_FILE="$PRE_COMPACT_LOCK_DIR/.pre-compact.lock"
PRE_COMPACT_DEDUP_FILE="$PRE_COMPACT_LOCK_DIR/.pre-compact.last-run"
PRE_COMPACT_DEDUP_WINDOW=30  # seconds — covers sequential dual-fire of one /compact

if command -v flock >/dev/null 2>&1; then
    exec 201>"$PRE_COMPACT_LOCK_FILE"
    if ! flock -n 201; then
        # Another pre-compact hook is mid-flight (concurrent case). Exit silently.
        exit 0
    fi
fi

# Time-window dedup (sequential case — flock can't help once the other run exited)
_pre_compact_now=$(date +%s)
if [ -f "$PRE_COMPACT_DEDUP_FILE" ]; then
    _pre_compact_last=$(cat "$PRE_COMPACT_DEDUP_FILE" 2>/dev/null)
    if [ -n "$_pre_compact_last" ] && [ "$_pre_compact_last" -gt 0 ] 2>/dev/null && \
       [ $((_pre_compact_now - _pre_compact_last)) -lt "$PRE_COMPACT_DEDUP_WINDOW" ]; then
        # A pre-compact ran very recently — this is the second hook fire. Skip.
        exit 0
    fi
fi
echo "$_pre_compact_now" > "$PRE_COMPACT_DEDUP_FILE" 2>/dev/null

HANDOVER_DEDUP_COOLDOWN=$(fw_config_int "HANDOVER_DEDUP_COOLDOWN" 300)

# Generate handover — always full quality (D-028)
# Deduplicate: skip commit if last commit was a handover within cooldown period
LAST_COMMIT_MSG=$(cd "$PROJECT_ROOT" && git log -1 --format="%s" 2>/dev/null)
LAST_COMMIT_AGE=$(cd "$PROJECT_ROOT" && git log -1 --format="%ct" 2>/dev/null)
NOW=$(date +%s)
SKIP_COMMIT=false
if echo "$LAST_COMMIT_MSG" | grep -qE "(handover|Handover)" 2>/dev/null; then
    if [ -n "$LAST_COMMIT_AGE" ] && [ $((NOW - LAST_COMMIT_AGE)) -lt "$HANDOVER_DEDUP_COOLDOWN" ]; then
        SKIP_COMMIT=true
    fi
fi

if [ "$SKIP_COMMIT" = "true" ]; then
    "$FRAMEWORK_ROOT/agents/handover/handover.sh" --no-commit 2>/dev/null
else
    "$FRAMEWORK_ROOT/agents/handover/handover.sh" --commit 2>/dev/null
fi

# Log the event
echo "[pre-compact] [manual] Handover generated at $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$PROJECT_ROOT/.context/working/.compact-log" 2>/dev/null

# Reset budget gate for THIS project so fresh session doesn't inherit critical lock (T-145)
echo "0" > "$PROJECT_ROOT/.context/working/.budget-gate-counter" 2>/dev/null
rm -f "$PROJECT_ROOT/.context/working/.budget-status" 2>/dev/null

exit 0
