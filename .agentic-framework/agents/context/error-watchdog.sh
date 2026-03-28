#!/bin/bash
# Error Watchdog — PostToolUse hook for Bash error detection
# Detects failed Bash commands and injects investigation reminder (L-037/FP-007)
#
# When a Bash command fails with a high-confidence error pattern, this hook
# outputs JSON with additionalContext telling the agent to investigate the
# root cause before proceeding — structural enforcement of CLAUDE.md §Error Protocol.
#
# Detection strategy (conservative to avoid false positives):
#   1. Only fires for Bash tool calls
#   2. Skips exit code 0 (success)
#   3. For exit code 1: only warns on high-confidence stderr patterns
#   4. For exit codes 126, 127, 137, 139: always warns (never benign)
#   5. For exit code >= 2: warns on pattern match
#
# Exit code: always 0 (PostToolUse hooks are advisory, cannot block)
# Output: JSON with additionalContext when errors detected, empty otherwise
#
# Part of: Agentic Engineering Framework
# Created by: T-118 (Silent Error Bypass Remediation)

set -uo pipefail

# Read stdin JSON from Claude Code
INPUT=$(cat)

# Parse and check in a single Python invocation (minimize overhead)
echo "$INPUT" | python3 -c "
import sys, json

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# Only check Bash tool calls
if data.get('tool_name') != 'Bash':
    sys.exit(0)

response = data.get('tool_response', {})
if not isinstance(response, dict):
    sys.exit(0)

exit_code = response.get('exitCode', 0)
if exit_code is None or exit_code == 0:
    sys.exit(0)

stderr = str(response.get('stderr', ''))
stdout = str(response.get('stdout', ''))
output = stderr + '\n' + stdout

# Exit codes that are NEVER benign (always warrant investigation)
CRITICAL_CODES = {
    126: 'Command not executable (permission or format issue)',
    127: 'Command not found',
    137: 'Process killed (SIGKILL — likely OOM)',
    139: 'Segmentation fault (SIGSEGV)',
}

# High-confidence error patterns (safe from false positives)
ERROR_PATTERNS = [
    'command not found',
    'Permission denied',
    'FATAL:',
    'ERROR:',
    'Traceback (most recent',
    'panic:',
    'Segmentation fault',
    'Cannot allocate memory',
    'Too many open files',
]

# Determine if this error warrants a warning
reason = None

# Check critical exit codes first
if exit_code in CRITICAL_CODES:
    reason = CRITICAL_CODES[exit_code]
else:
    # Check for high-confidence patterns in output
    output_lower = output.lower()
    for pattern in ERROR_PATTERNS:
        if pattern.lower() in output_lower:
            # Find the actual matching line for context
            for line in output.split('\n'):
                if pattern.lower() in line.lower():
                    reason = line.strip()[:150]
                    break
            break

if reason:
    result = {
        'hookSpecificOutput': {
            'hookEventName': 'PostToolUse',
            'additionalContext': (
                f'ERROR WATCHDOG (exit {exit_code}): {reason}\n'
                'INVESTIGATE the root cause before proceeding. '
                'Do NOT silently switch to an alternative path. '
                'Report what failed and why to the user. '
                '(CLAUDE.md Error Protocol, L-037)'
            )
        }
    }
    print(json.dumps(result))
" 2>/dev/null

exit 0
