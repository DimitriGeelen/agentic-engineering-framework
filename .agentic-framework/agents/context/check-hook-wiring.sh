#!/bin/bash
# check-hook-wiring — PreToolUse hook (matcher Write|Edit|Bash): the operator wires hooks
# (operator ruling 2026-11-24, T-5403). An agent's Write/Edit that changes the hook wiring of
# .claude/settings.json (or settings.local.json), or a Bash write to those files, is refused;
# the agent prepares the change with `fw hook-wiring propose` and hands over the runme.
#
# The verdict lives in lib/hook_wiring.py (`check`). The matcher routes every Write, Edit
# and Bash call here, so a crash must not refuse them all: it fails closed only when the
# payload names a settings file.
#
# Exit: 0 allow, 2 refuse.

FRAMEWORK_ROOT="${FRAMEWORK_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT_ROOT="${PROJECT_ROOT:-${CLAUDE_PROJECT_DIR:-$(pwd)}}"

payload=$(cat 2>/dev/null) || payload=""

_fail() {
    case "$payload" in
        *settings.json*|*settings.local.json*)
            echo "FW-DENY: hook-wiring (T-5403)" >&2
            echo "BLOCKED: $1 — the hook wiring gate cannot judge a call that names .claude settings; fail closed." >&2
            exit 2 ;;
    esac
    exit 0
}

if ! command -v python3 >/dev/null 2>&1 || [ ! -f "$FRAMEWORK_ROOT/lib/hook_wiring.py" ]; then
    _fail "python3 or lib/hook_wiring.py missing"
fi

printf '%s' "$payload" | PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    python3 "$FRAMEWORK_ROOT/lib/hook_wiring.py" check
rc=$?
[ "$rc" -eq 0 ] && exit 0
[ "$rc" -eq 2 ] && exit 2
_fail "the gate exited $rc (crash)"
