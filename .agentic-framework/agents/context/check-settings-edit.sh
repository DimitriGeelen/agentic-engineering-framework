#!/bin/bash
# Enforcement-baseline refresh nudge — PostToolUse hook for Write|Edit on .claude/settings.json
# When the agent edits .claude/settings.json (adding/removing/reorganising hooks), emits an
# advisory reminder to add `bin/fw enforcement baseline` to the active task's Verification
# block. Otherwise the canonical hash diverges and `fw doctor` reports FAIL.
#
# Exit code: always 0 (advisory only, never blocks).
# Output: JSON with additionalContext when reminder needed; nothing otherwise.
#
# Origin: T-1886 RCA Candidate B — deployed after T-1887 Candidate A (template hint).
# Pairs with L-398. See also: T-1849, T-1730, T-1731 (the hook-additions that originally
# left the baseline in FAIL across multiple sessions).

set -uo pipefail

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = data.get('tool_name', '')
if tool_name not in ('Write', 'Edit'):
    sys.exit(0)

tool_input = data.get('tool_input', {})
if isinstance(tool_input, str):
    try:
        tool_input = json.loads(tool_input)
    except Exception:
        sys.exit(0)

file_path = tool_input.get('file_path', '')
if not file_path:
    sys.exit(0)

# Match either absolute or relative reference to .claude/settings.json
basename = os.path.basename(file_path)
parent = os.path.basename(os.path.dirname(file_path))
if basename != 'settings.json' or parent != '.claude':
    sys.exit(0)

msg = (
    'L-398 reminder: you just edited .claude/settings.json. '
    'Add \`bin/fw enforcement baseline\` to your current task\\'s ## Verification block '
    'so the canonical hash refreshes at task close. Otherwise fw doctor will report '
    '\"Enforcement baseline CHANGED\" until somebody cleans up (origin: T-1886, T-1887).'
)

result = {
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': msg
    }
}
print(json.dumps(result))
" 2>/dev/null || true
