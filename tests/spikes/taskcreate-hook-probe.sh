#!/bin/bash
# tests/spikes/taskcreate-hook-probe.sh (T-1115/T-1116)
#
# Verification spike: does Claude Code fire PreToolUse hooks on its
# built-in TaskCreate/TaskUpdate/TaskList/TaskGet tools?
#
# This script is a no-op probe: it logs every invocation to
# .context/working/.taskcreate-probe.log and exits 0 (allow). Run in a
# fresh Claude Code session after merging
# tests/spikes/taskcreate-hook-probe-settings-fragment.json into
# .claude/settings.json.
#
# If the log fills up after Task* tool calls → A1 (hookability) TRUE
# → proceed with T-1115 Phase 2 Level 1 implementation.
#
# If the log stays empty after confirmed Task* tool calls → A1 FALSE
# → proceed with T-1115 Phase 2 fallback (CLAUDE.md rule + PostToolUse
# scanner).

set -eu

# PROJECT_ROOT resolution: framework first, consumer fallback
if [ -n "${PROJECT_ROOT:-}" ] && [ -d "$PROJECT_ROOT/.context" ]; then
    log_dir="$PROJECT_ROOT/.context/working"
elif [ -d "/opt/999-Agentic-Engineering-Framework/.context" ]; then
    log_dir="/opt/999-Agentic-Engineering-Framework/.context/working"
else
    # Last resort — walk up from script location
    here="$(cd "$(dirname "$0")" && pwd)"
    while [ "$here" != "/" ] && [ ! -d "$here/.context" ]; do
        here="$(dirname "$here")"
    done
    log_dir="$here/.context/working"
fi

mkdir -p "$log_dir"
log_file="$log_dir/.taskcreate-probe.log"

# Capture stdin (Claude Code hooks receive the tool_input as JSON on stdin)
stdin_payload=""
if [ -p /dev/stdin ] || [ ! -t 0 ]; then
    stdin_payload=$(cat)
fi

# Write a compact log line
{
    printf '%s ' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'pid=%s ' "$$"
    printf 'argv=[%s] ' "$*"
    printf 'stdin=%s' "$(printf '%s' "$stdin_payload" | tr -d '\n' | head -c 500)"
    printf '\n'
} >> "$log_file"

# Always allow (exit 0). This is a probe, not an enforcement.
exit 0
