#!/usr/bin/env bash
# sidecar-receiver-ready.sh — Stop hook: the turn ended, the agent is ready for input.
#
# T-3693 (arc-011 slice 1, finishing T-3561). Registered alongside stop-driver.sh
# (arc-012) in the Stop phase; the two are independent. Readiness is
# self-reported by the harness (T-3397 §Findings): this sets
# .context/sidecar/ready-for-input.yaml to ready: true. The UserPromptSubmit
# hook (sidecar-receiver-adapter.sh) clears it.
#
# Body: lib/sidecar/hooks.py stop. Fails open (exit 0) — never blocks a turn —
# but a Python error is logged to .context/sidecar/receiver/hook-errors.log.
#
# Invoked as: fw hook sidecar-receiver-ready

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$FRAMEWORK_ROOT}}"
export FRAMEWORK_ROOT PROJECT_ROOT

python3 "$FRAMEWORK_ROOT/lib/sidecar/hooks.py" stop || true
exit 0
