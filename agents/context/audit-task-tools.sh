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

echo "$INPUT" | python3 -c "
import sys, json

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
    f'Use bin/fw work-on to create real tasks. '
    f'If the PreToolUse block did not fire, check .claude/settings.json for the '
    f'TodoWrite matcher (T-1117). This may indicate a sub-agent bypass (issue 45427 FM1).'
)

json.dump({'additionalContext': msg}, sys.stdout)
" 2>/dev/null || true

exit 0
