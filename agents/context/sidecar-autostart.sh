#!/usr/bin/env bash
# sidecar-autostart.sh — SessionStart hook: every agent runs a sidecar (R14).
#
# T-3685 (arc-011 S-LIVE). claude-fw starts the project's sidecar (receiver +
# supervised watcher) for its own sessions; this covers every OTHER launch —
# a plain `claude`, an IDE, a dispatched worker — so no agent session in a
# framework project runs without one. It runs `fw sidecar ensure --autostart`
# DETACHED and returns at once: a session start never waits on it.
#
#   --autostart: enabled → (re)start a dead or stale supervisor/receiver;
#                never started here → start it;
#                explicitly stopped (`fw sidecar stop`) → leave it stopped.
#
# Skipped inside a review worker (its environment is the review brief only),
# inside a dispatched worker (T-4416: it never owns the project sidecar; a
# restart from here carried its pane and agent id into the project's processes)
# and when FW_SIDECAR_AUTOSTART=0. `ensure` itself also refuses a session
# addressed as another agent (FW_SIDECAR_AGENT_ID != project agent).
# Fails open, silently: a sidecar fault never blocks a session; `fw doctor` / `fw audit` report a missing or dead one.
#
# T-5014: also claims the project's main lease for an interactive session (see below).
#
# Invoked as: fw hook sidecar-autostart

set -u
HOOK_INPUT="$(cat 2>/dev/null || true)"
[ -n "${FW_REVIEW_WORKER:-}" ] && exit 0
[ "${FW_SIDECAR_AUTOSTART:-1}" = "0" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$FRAMEWORK_ROOT}}"
export FRAMEWORK_ROOT PROJECT_ROOT
[ -d "$PROJECT_ROOT/.context" ] || exit 0

mkdir -p "$PROJECT_ROOT/.context/sidecar/watcher" 2>/dev/null || exit 0
if [ "${FW_DISPATCHED_WORKER:-}" = "1" ]; then
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) autostart skipped: FW_DISPATCHED_WORKER=1 (agent ${FW_SIDECAR_AGENT_ID:-?}) — a dispatched worker never (re)starts the project sidecar (T-4416)" \
        >>"$PROJECT_ROOT/.context/sidecar/watcher/autostart.log" 2>/dev/null || true
    exit 0
fi
# T-5014: an interactive session claims the project's main lease. hooks.py decides
# who may claim (never headless `claude -p`, review seats or dispatched workers)
# and runs only the claim itself detached; it returns at once and fails open.
printf '%s' "$HOOK_INPUT" | ( cd "$PROJECT_ROOT" && timeout 5 python3 "$FRAMEWORK_ROOT/lib/sidecar/hooks.py" session-start ) >/dev/null 2>&1 || true
( cd "$PROJECT_ROOT" && setsid nohup python3 "$FRAMEWORK_ROOT/lib/sidecar_cli.py" ensure --autostart \
    >>"$PROJECT_ROOT/.context/sidecar/watcher/autostart.log" 2>&1 </dev/null & ) >/dev/null 2>&1
exit 0
