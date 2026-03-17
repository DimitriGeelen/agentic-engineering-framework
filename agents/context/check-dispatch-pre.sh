#!/bin/bash
# Dispatch Pre-Gate — PreToolUse hook for Task tool calls
# Validates preamble inclusion before sub-agent dispatch (G-008 enforcement)
#
# Three incidents (T-073: 177K spike, T-158, T-170) proved that unbounded
# sub-agent output crashes sessions. PostToolUse advisory (check-dispatch.sh)
# warns AFTER the damage. This hook prevents dispatch WITHOUT preamble.
#
# Detection:
#   1. Only fires for Task tool calls (not TaskOutput)
#   2. Checks if prompt contains preamble markers
#   3. Blocks if markers are absent (exit code 2)
#
# Exempt dispatches:
#   - Explore agents (short-lived, typically small output)
#   - Plan agents (advisory output, typically concise)
#   - Haiku model agents (lightweight, small output)
#   - Resume of existing agents (prompt field is minimal)
#
# Exit code: 0 (allow) or 2 (block)
#
# Part of: Agentic Engineering Framework (G-008: Dispatch Enforcement, T-509)

set -uo pipefail

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool_name = data.get('tool_name', '')

# Only check Task tool calls
if tool_name != 'Task':
    sys.exit(0)

# Extract tool input (the parameters passed to Task)
tool_input = data.get('tool_input', {})
if not tool_input:
    sys.exit(0)

# Resuming an existing agent — no preamble needed
if tool_input.get('resume'):
    sys.exit(0)

prompt = tool_input.get('prompt', '')
subagent_type = (tool_input.get('subagent_type', '') or '').lower()

# Explore agents are exempt — short-lived, read-only, small output
if subagent_type == 'explore':
    sys.exit(0)

# Plan agents are exempt — advisory output, typically concise
if subagent_type == 'plan':
    sys.exit(0)

# Haiku model agents are exempt — lightweight, small output
model = (tool_input.get('model', '') or '').lower()
if model == 'haiku':
    sys.exit(0)

# Special agent types that don't produce large output
exempt_types = {'statusline-setup', 'claude-code-guide'}
if subagent_type in exempt_types:
    sys.exit(0)

prompt_lower = prompt.lower()

# Check for preamble markers — distinctive strings from preamble.md
# We check for the EFFECT of the preamble (output discipline), not exact text
preamble_markers = [
    'write',          # 'Write all detailed output to disk' or 'write to /tmp'
    '/tmp/fw-agent',  # Output file convention
    'summary',        # 'return only path + summary'
]

# Need at least 2 of 3 markers (fuzzy match — allows paraphrasing)
marker_hits = sum(1 for m in preamble_markers if m in prompt_lower)
if marker_hits >= 2:
    sys.exit(0)

# Also accept explicit conciseness instructions
concise_markers = ['concise', 'brief', '5 lines', 'five lines', '<=5', '≤5', 'return only']
if any(m in prompt_lower for m in concise_markers):
    sys.exit(0)

# Block — preamble not detected
result = {
    'decision': 'block',
    'reason': (
        'DISPATCH GATE (T-509): Sub-agent prompt missing output discipline preamble.\\n'
        'Sub-agents that return full content instead of writing to disk crash sessions (T-073: 177K spike).\\n'
        '\\n'
        'REQUIRED: Include these instructions in your dispatch prompt:\\n'
        '  - \"Write detailed output to /tmp/fw-agent-{name}.md\"\\n'
        '  - \"Return only path + summary (<=5 lines)\"\\n'
        '\\n'
        'Full preamble: cat agents/dispatch/preamble.md\\n'
        'Exempt: Explore agents, Plan agents, haiku model, resumed agents'
    )
}

print(json.dumps(result))
sys.exit(2)
" 2>/dev/null
python_exit=$?

# Propagate Python's exit code (2 = block, 0 = allow)
# If Python itself fails (syntax error, not found), fail open
if [ $python_exit -eq 2 ]; then
    exit 2
fi
exit 0
