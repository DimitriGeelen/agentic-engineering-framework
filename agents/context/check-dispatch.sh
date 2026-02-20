#!/bin/bash
# Dispatch Guard — PostToolUse hook for Task/TaskOutput result size
# Warns when sub-agent results exceed safe thresholds (G-008 enforcement)
#
# Three incidents (T-073, T-158, T-170) proved that unbounded tool output
# crashes sessions. This hook provides a structural warning layer.
#
# Detection:
#   1. Only fires for Task and TaskOutput tool calls
#   2. Measures tool_response content length
#   3. Warns if >5K chars (indicates agent returned content instead of writing to disk)
#
# Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
# Output: JSON with additionalContext when oversized results detected
#
# Part of: Agentic Engineering Framework (G-008: Dispatch Enforcement)
# Created by: T-225

set -uo pipefail

# Read stdin JSON from Claude Code
INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = data.get('tool_name', '')

# Only check Task and TaskOutput tool calls
if tool_name not in ('Task', 'TaskOutput'):
    sys.exit(0)

response = data.get('tool_response', '')
if not response:
    sys.exit(0)

# Measure response size
if isinstance(response, dict):
    content = json.dumps(response)
elif isinstance(response, str):
    content = response
else:
    content = str(response)

size = len(content)

# Thresholds
WARN_SIZE = 5000       # 5K chars — agent likely returned content inline
CRITICAL_SIZE = 20000  # 20K chars — definite context flood

if size < WARN_SIZE:
    sys.exit(0)

# Build warning message
if size >= CRITICAL_SIZE:
    severity = 'CRITICAL'
    advice = (
        f'DISPATCH GUARD ({severity}): {tool_name} returned {size:,} chars — CONTEXT FLOOD RISK.\n'
        'This result is dangerously large. The sub-agent likely returned full content instead of writing to disk.\n'
        'REQUIRED ACTIONS:\n'
        '1. Do NOT dispatch more sub-agents until context is assessed\n'
        '2. Check budget: ./agents/context/checkpoint.sh status\n'
        '3. Future dispatches MUST include the preamble from agents/dispatch/preamble.md\n'
        '4. Sub-agents must write to /tmp/fw-agent-*.md and return only path + summary (<=5 lines)'
    )
else:
    severity = 'WARNING'
    advice = (
        f'DISPATCH GUARD ({severity}): {tool_name} returned {size:,} chars (threshold: 5,000).\n'
        'Sub-agent may have returned inline content instead of writing to disk.\n'
        'REMINDER: Include the preamble from agents/dispatch/preamble.md in all dispatch prompts.\n'
        'Sub-agents should write detailed output to /tmp/fw-agent-*.md and return <=5 lines.'
    )

result = {
    'hookSpecificOutput': {
        'hookEventName': 'PostToolUse',
        'additionalContext': advice
    }
}

print(json.dumps(result))
" 2>/dev/null || true
