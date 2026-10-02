#!/usr/bin/env bash
# sidecar-receiver-adapter.sh — UserPromptSubmit hook: surface receiver messages.
#
# T-3693 (arc-011 slice 1, finishing T-3561). Registered alongside
# sidecar-inbox.sh (T-3407, the hub-topic surface). This one reads the local
# receiver's store (`fw sidecar receiver start`):
#   1. clears ready-for-input FIRST — the agent is busy from this instant
#   2. emits the stored, not-yet-handed-over messages as additionalContext,
#      framed as untrusted data
#   3. only then records HANDED_OVER and posts CONFIRM-2 to the sender
#
# Body: lib/sidecar/hooks.py prompt. Fails open (exit 0) — a sidecar fault
# never blocks a prompt — but errors go to .context/sidecar/receiver/hook-errors.log.
#
# Invoked as: fw hook sidecar-receiver-adapter

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$FRAMEWORK_ROOT}}"
export FRAMEWORK_ROOT PROJECT_ROOT

python3 "$FRAMEWORK_ROOT/lib/sidecar/hooks.py" prompt || true
exit 0
