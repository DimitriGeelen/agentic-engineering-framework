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
# Skipped inside a review worker (its environment is the review brief only)
# and when FW_SIDECAR_AUTOSTART=0. Fails open, silently: a sidecar fault never
# blocks a session; `fw doctor` / `fw audit` report a missing or dead one.
#
# Invoked as: fw hook sidecar-autostart

set -u
cat >/dev/null 2>&1 || true
[ -n "${FW_REVIEW_WORKER:-}" ] && exit 0
[ "${FW_SIDECAR_AUTOSTART:-1}" = "0" ] && exit 0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$FRAMEWORK_ROOT}}"
export FRAMEWORK_ROOT PROJECT_ROOT
[ -d "$PROJECT_ROOT/.context" ] || exit 0

mkdir -p "$PROJECT_ROOT/.context/sidecar/watcher" 2>/dev/null || exit 0
( cd "$PROJECT_ROOT" && setsid nohup python3 "$FRAMEWORK_ROOT/lib/sidecar_cli.py" ensure --autostart \
    >>"$PROJECT_ROOT/.context/sidecar/watcher/autostart.log" 2>&1 </dev/null & ) >/dev/null 2>&1
exit 0
