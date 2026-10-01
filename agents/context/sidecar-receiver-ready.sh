#!/usr/bin/env bash
# sidecar-receiver-ready.sh — Stop hook: mark agent as ready to receive injected messages.
#
# T-3693 (arc-011 slice 1). Runs when the Stop hook fires (at the end of a turn,
# when the agent is idle and awaiting input):
#   1. Set the ready-for-input flag
#   2. Check if there are pending messages
#   3. If ready and pending, trigger injection via TermLink
#
# This is a sibling to stop-driver.sh (arc-012). Both run in the Stop hook phase.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
export FRAMEWORK_ROOT PROJECT_ROOT

FW_BIN="${FW_BIN:-$FRAMEWORK_ROOT/bin/fw}"
[ -x "$FW_BIN" ] || exit 0

# Mark the agent as ready to receive injected messages
python3 << 'PYTHON_EOF' 2>/dev/null || exit 0
import sys
import os
import json

try:
    sys.path.insert(0, os.path.expandvars("${FRAMEWORK_ROOT}"))
    from lib.sidecar import adapter, lifecycle

    # Step 1: Set the ready-for-input flag
    adapter.set_ready_for_input(True)

    # Step 2: Check if receiver is running and has pending messages
    info = lifecycle.read_triple_file()
    if not info:
        # Receiver not running — nothing to do
        sys.exit(0)

    if not lifecycle.is_receiver_alive(info):
        # Receiver is stale — clean up triple file
        lifecycle.clear_triple_file()
        sys.exit(0)

    # Step 3: If there are pending messages, trigger injection via TermLink
    # (The actual injection happens in the UserPromptSubmit hook when the
    # agent's session is ready to receive input. This just sets the flag.)

except Exception:
    # Fail silently: the Stop hook must not block the agent's turn
    pass

exit 0
