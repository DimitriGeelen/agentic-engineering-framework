#!/bin/bash
# PostToolUse scanner: detect TodoWrite/TaskCreate usage (T-1115/T-1118)
#
# Belt-and-braces detector. Even with PreToolUse block (T-1117), sub-agents
# can bypass hooks (issue 45427 FM1). This scanner catches any successful
# TodoWrite/TaskCreate call and warns the agent via additionalContext.
#
# Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
# Output: JSON with additionalContext when banned tool detected, empty otherwise

set -uo pipefail

INPUT=$(cat)
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-${PROJECT_ROOT:-$(pwd)}}"
# Printed-command builder (T-5304): side-effect free, safe to source in a hook.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/lib/fw-command.sh" 2>/dev/null || _emit_user_command() { printf 'bin/fw %s\n' "$1"; }
export FW_HINT_WORKON="$(_emit_user_command "work-on")"

echo "$INPUT" | python3 -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = data.get('tool_name', '')
BANNED = {'TodoWrite', 'TaskCreate', 'TaskUpdate', 'TaskList', 'TaskGet'}

if tool not in BANNED:
    sys.exit(0)

msg = (
    f'WARNING: Built-in {tool} tool was invoked. This bypasses framework governance. '
    f'Use {os.environ.get(\"FW_HINT_WORKON\", \"bin/fw work-on\")} to create real tasks. '
    f'If the PreToolUse block did not fire, check .claude/settings.json for the '
    f'TodoWrite matcher (T-1117). This may indicate a sub-agent bypass (issue 45427 FM1).'
)

json.dump({'additionalContext': msg}, sys.stdout)
" 2>/dev/null || true

exit 0
