#!/usr/bin/env bash
# sidecar-adapter2.sh — Claude Code adapter for TermLink's termlink.adapter/2 contract (T-5054).
#
# Registered on PreToolUse, PostToolUse and SessionEnd with the hook name as its one
# argument (pre-tool | post-tool | session-end). The prompt, stop and session-start
# reports are sent from lib/sidecar/hooks.py, because the lease claim needs the
# receiver's origin_checked in the same process (docs/reports/T-5054-adapter2-design.md).
#
# Body: lib/sidecar/adapter2.py. Off unless TERMLINK_ADAPTER2=1 and a sidecar socket is
# configured. Fails open (exit 0) — never blocks a tool call; a fault is logged by the
# adapter to .context/sidecar/receiver/hook-errors.log. `python3 -S` keeps the off path
# cheap: it runs on every tool call.
#
# Invoked as: fw hook sidecar-adapter2 <pre-tool|post-tool|session-end>

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$FRAMEWORK_ROOT}}"
export FRAMEWORK_ROOT PROJECT_ROOT

case "${1:-}" in
    pre-tool|post-tool|session-end)
        python3 -S "$FRAMEWORK_ROOT/lib/sidecar/adapter2.py" "$1" || true ;;
esac
exit 0
