#!/bin/bash
# Tier 0 Enforcement Hook — PreToolUse gate for Bash tool
# Detects destructive commands and blocks them unless explicitly approved.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Flow:
#   1. Extract bash command from stdin JSON
#   2. Quick keyword check (bash grep — no Python overhead for safe commands)
#   3. If keywords found, Python detailed pattern matching
#   4. If destructive pattern matched:
#      a. Check for one-time approval token
#      b. If valid approval: allow, log, delete token
#      c. If no approval: block with explanation
#   5. If no match: allow
#
# Part of: Agentic Engineering Framework
# Spec: 011-EnforcementConfig.md §Tier 0 (Unconditional Enforcement)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
APPROVAL_FILE="$PROJECT_ROOT/.context/working/.tier0-approval"

# Read stdin JSON from Claude Code
INPUT=$(cat)

# Extract the bash command via Python (handles JSON properly)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

# If no command extracted, allow (defensive — don't block on parse failure)
if [ -z "$COMMAND" ]; then
    exit 0
fi

# ── Fast path: keyword pre-filter (bash grep, no Python overhead) ──
# Only invoke Python if the command MIGHT be destructive.
# This keeps the hook fast (<5ms) for the 95%+ of safe commands.
if ! echo "$COMMAND" | grep -qEi \
    'git\s+(push|reset|clean|checkout|restore|branch)\s|rm\s+-|DROP\s|TRUNCATE\s|docker\s+system|kubectl\s+delete'; then
    exit 0
fi

# ── Detailed pattern matching (Python — only reached for suspicious commands) ──
MATCH_RESULT=$(echo "$COMMAND" | python3 -c "
import re, sys

command = sys.stdin.read().strip()

# Strip quoted string contents to avoid false positives on commit messages,
# echo arguments, heredocs, and embedded Python/test code.
# This is an approximation — perfect shell parsing is impossible in regex.
def strip_quotes(cmd):
    # Remove single-quoted string contents (no escaping inside single quotes in sh)
    cmd = re.sub(r\"'[^']*'\", \"''\", cmd)
    # Remove double-quoted string contents (approximate)
    cmd = re.sub(r'\"[^\"]*\"', '\"\"', cmd)
    return cmd

command_stripped = strip_quotes(command)

# Tier 0 destructive patterns — high confidence, low false positive
# Each tuple: (regex_pattern, risk_description)
PATTERNS = [
    # === Git destructive operations ===
    (r'\bgit\s+push\b[^;|&]*(-f\b|--force\b|--force-with-lease\b)',
     'FORCE PUSH: Can overwrite remote commit history'),
    (r'\bgit\s+reset\s+--hard\b',
     'HARD RESET: Permanently discards all uncommitted changes'),
    (r'\bgit\s+clean\b[^;|&]*-[a-zA-Z]*f',
     'GIT CLEAN: Permanently removes untracked files'),
    (r'\bgit\s+(checkout|restore)\s+\.\s*(\s*$|[;&|])',
     'RESTORE ALL: Discards all unstaged changes in working directory'),
    (r'\bgit\s+branch\s+[^;|&]*-D\b',
     'FORCE DELETE BRANCH: Deletes branch even if changes are unmerged'),

    # === Catastrophic file deletion ===
    # rm with recursive flag targeting dangerous paths
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+/(\s|$|;|&|\*)',
     'RECURSIVE DELETE: Targets root filesystem (/)'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+(~|\\\$HOME)(\s|$|;|&|/)',
     'RECURSIVE DELETE: Targets home directory'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+\.\s*($|[;&|])',
     'RECURSIVE DELETE: Targets current directory (.)'),
    (r'\brm\s+[^;|&]*-[a-zA-Z]*[rR][a-zA-Z]*[^;|&]*\s+\*(\s|$|;|&)',
     'RECURSIVE DELETE: Targets everything via wildcard (*)'),

    # === Database destructive ===
    (r'(?i)\bDROP\s+(TABLE|DATABASE|SCHEMA)\b',
     'SQL DROP: Permanent data destruction'),
    (r'(?i)\bTRUNCATE\s+TABLE\b',
     'SQL TRUNCATE: Permanent data destruction'),

    # === Infrastructure destructive ===
    (r'\bdocker\s+system\s+prune\b',
     'DOCKER PRUNE: Removes all unused containers, networks, images'),
    (r'\bkubectl\s+delete\s+(namespace|ns)\s',
     'K8S NAMESPACE DELETE: Removes namespace and all resources in it'),
]

for pattern, description in PATTERNS:
    if re.search(pattern, command_stripped):
        print(f'BLOCKED|{description}')
        sys.exit(0)

print('SAFE')
" 2>/dev/null)

# If Python failed or returned SAFE, allow
if [ -z "$MATCH_RESULT" ] || [ "$MATCH_RESULT" = "SAFE" ]; then
    exit 0
fi

# ── Destructive pattern detected ──
DESCRIPTION="${MATCH_RESULT#BLOCKED|}"

# Compute command hash for approval matching
COMMAND_HASH=$(echo -n "$COMMAND" | sha256sum | awk '{print $1}')

# ── Check for valid approval token ──
if [ -f "$APPROVAL_FILE" ]; then
    APPROVAL_HASH=$(awk '{print $1}' "$APPROVAL_FILE" 2>/dev/null)
    APPROVAL_TIME=$(awk '{print $2}' "$APPROVAL_FILE" 2>/dev/null)
    CURRENT_TIME=$(date +%s)

    if [ "$APPROVAL_HASH" = "$COMMAND_HASH" ]; then
        AGE=$((CURRENT_TIME - ${APPROVAL_TIME:-0}))
        if [ "$AGE" -lt 300 ]; then
            # Valid approval — consume it and allow
            rm -f "$APPROVAL_FILE"

            # Log to bypass-log for audit trail (fire-and-forget)
            python3 -c "
import yaml, datetime, os

log_file = os.path.join('$PROJECT_ROOT', '.context', 'bypass-log.yaml')
entry = {
    'timestamp': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'tier': 0,
    'risk': '$DESCRIPTION',
    'command_preview': '''${COMMAND:0:120}''',
    'command_hash': '$COMMAND_HASH',
    'authorized_by': 'human',
    'mechanism': 'fw tier0 approve',
}
try:
    if os.path.exists(log_file):
        with open(log_file) as f:
            data = yaml.safe_load(f) or {}
    else:
        data = {}
    data.setdefault('bypasses', []).append(entry)
    with open(log_file, 'w') as f:
        yaml.dump(data, f, default_flow_style=False, sort_keys=False)
except:
    pass
" 2>/dev/null &
            exit 0
        fi
    fi

    # Stale or mismatched approval — clean up
    rm -f "$APPROVAL_FILE"
fi

# ── Block with explanation ──
echo "" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "  TIER 0 BLOCK — Destructive Command Detected" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "" >&2
echo "  Risk: $DESCRIPTION" >&2
echo "  Command: ${COMMAND:0:120}" >&2
echo "" >&2
echo "  This command is classified as Tier 0 (consequential)." >&2
echo "  It requires explicit human approval before execution." >&2
echo "" >&2
echo "  To proceed (after the human approves):" >&2
echo "    ./bin/fw tier0 approve" >&2
echo "  Then retry the same command." >&2
echo "" >&2
echo "  Policy: 011-EnforcementConfig.md §Tier 0" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "" >&2

# Write the pending command hash so 'fw tier0 approve' can pick it up
echo "$COMMAND_HASH $(date +%s) PENDING" > "${APPROVAL_FILE}.pending"

exit 2
