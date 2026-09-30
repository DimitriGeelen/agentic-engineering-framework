#!/bin/bash
# check-paid-backend — PreToolUse hook (Bash): paid review backends need an approved proposal.
#
# T-3583 operator ruling: every review or dispatch has a cost; a PAID backend (openrouter,
# and anything the operator classes paid in policy/review-backends.yaml) is used only
# against an approved, unused proposal for the focused task. Internal backends are allowed
# and reminded to log their cost.
#
# Detection is data, not code: each backend's `match:` regexes in the registry (default:
# its id as a word). lib/review_cost.py check-command owns the verdict; this wrapper only
# extracts the command and the focused task.
#
# T-3586 rebuilt this. The T-3583 version read the command from "$1" (hooks receive JSON on
# stdin, so it saw "." and never fired), read `task:` from focus.yaml (the key is
# `current_task:`), matched approvals on a record shape the approve step never wrote, and
# was registered by absolute path instead of through `fw hook`.
#
# Scope: like Tier 0 it sees only the typed command string — a script that calls a paid
# API internally is not inspected (CLAUDE.md §Enforcement Tiers, T-2742).
#
# Exit: 0 allow (reminder on stderr), 2 block.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-paid-backend"

INPUT=$(cat)
COMMAND=$(printf '%s' "$INPUT" | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null)
[ -z "$COMMAND" ] && exit 0

TASK=""
_focus="$(fw_focus_file "$PROJECT_ROOT" 2>/dev/null)"
[ -f "$_focus" ] || _focus="$PROJECT_ROOT/.context/working/focus.yaml"
if [ -f "$_focus" ]; then
    TASK=$(sed -n 's/^current_task:[[:space:]]*//p' "$_focus" | head -1 | tr -d "\"' ")
    [ "$TASK" = "null" ] && TASK=""
fi

printf '%s' "$COMMAND" | PROJECT_ROOT="$PROJECT_ROOT" FRAMEWORK_ROOT="$FRAMEWORK_ROOT" \
    python3 "$FRAMEWORK_ROOT/lib/review_cost.py" check-command --task "$TASK"
rc=$?
[ "$rc" -eq 2 ] && exit 2
exit 0
