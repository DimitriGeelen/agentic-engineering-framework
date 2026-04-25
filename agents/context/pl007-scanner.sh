#!/bin/bash
# REFERENCE ONLY — not registered in .claude/settings.json (see T-1459)
# PL-007 Scanner — PostToolUse hook that flags bare command patterns in Bash output
#
# When a Bash tool result contains text that looks like a command the agent might
# relay verbatim to the user (e.g. `fw inception decide T-XXX go`), inject a
# reminder that PL-007 says: DO NOT output bare commands; execute them or use the
# push-based delivery channel (fw task review / termlink inject).
#
# Detection strategy:
#   1. Only fires for Bash tool calls.
#   2. Skips when the agent's own command string already contains the pattern
#      (i.e. the agent ran `fw inception decide ...` — not relaying, executing).
#   3. Skips when the command being run is `fw task review` (legitimate precursor
#      that normally prints these commands for the HUMAN review flow).
#   4. On match, emits additionalContext reminding the agent of PL-007.
#
# Exit code: always 0 (PostToolUse hooks are advisory).
#
# Part of: Agentic Engineering Framework
# Created by: T-1187 (pl007-scanner — T-976 Agent ACs claimed exists but artifact absent)

set -uo pipefail

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, re

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if data.get('tool_name') != 'Bash':
    sys.exit(0)

tool_input = data.get('tool_input', {}) or {}
command = str(tool_input.get('command', ''))

# Skip if the agent just ran 'fw task review' — that flow is supposed to print
# these commands for the HUMAN review channel, not for relay.
if re.search(r'\bfw\s+task\s+review\b', command):
    sys.exit(0)

response = data.get('tool_response', {})
if not isinstance(response, dict):
    sys.exit(0)

stdout = str(response.get('stdout', ''))
stderr = str(response.get('stderr', ''))
output = stdout + '\n' + stderr

# Bare-command patterns that typically appear in tool output intended for the HUMAN.
# If the agent sees these in output, it must NOT relay them verbatim to the user.
BARE_PATTERNS = [
    (r'\bfw\s+inception\s+decide\s+T-\d+', 'fw inception decide'),
    (r'\bfw\s+tier0\s+approve\b', 'fw tier0 approve'),
    (r'\bbin/fw\b', 'bin/fw'),
]

hits = []
for pat, label in BARE_PATTERNS:
    if re.search(pat, output):
        # If the agent's own command already contains this same pattern, suppress
        # — the agent is executing, not relaying.
        if re.search(pat, command):
            continue
        hits.append(label)

if hits:
    labels = ', '.join(sorted(set(hits)))
    msg = (
        f'PL-007 REMINDER: tool output contains bare command pattern(s): {labels}. '
        'Do NOT relay these commands to the user verbatim in your text response. '
        'Either execute them directly, or use the push-based channel '
        '(fw task review / termlink inject). '
        '(Learning PL-007 — feedback given 3+ times; structural reminder.)'
    )
    result = {
        'hookSpecificOutput': {
            'hookEventName': 'PostToolUse',
            'additionalContext': msg,
        }
    }
    print(json.dumps(result))
" 2>/dev/null

exit 0
