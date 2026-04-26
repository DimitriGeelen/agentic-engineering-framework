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
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
source "$FRAMEWORK_ROOT/lib/watchtower.sh"
fw_hook_crash_trap "check-tier0"
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
    'git\s+(push|reset|clean|checkout|restore|branch)\s|--no-verify|rm\s+-|DROP\s|TRUNCATE\s|docker\s+system|kubectl\s+delete|find\s.*-delete|dd\s+if=|chmod\s.*\s000|mkfs|pkill\s|fw\s.*--force|fw\s.*inception\s.*decide'; then
    exit 0
fi

# ── Detailed pattern matching (Python — only reached for suspicious commands) ──
MATCH_RESULT=$(echo "$COMMAND" | python3 -c "
import re, sys

command = sys.stdin.read().strip()

# Strip heredoc body contents to avoid false positives on embedded text.
# Matches: <<[-]?['\"']?WORD['\"']? ... WORD (on own line)
def strip_heredocs(cmd):
    return re.sub(
        r'(<<-?\s*)[\'\"]?(\w+)[\'\"]?([^\n]*\n)'
        r'.*?'
        r'(\n[ \t]*\2[ \t]*(?:\n|$))',
        r'\1\2\3\4',
        cmd,
        flags=re.DOTALL,
    )

# Strip quoted string contents to avoid false positives on commit messages,
# echo arguments, and embedded Python/test code.
def strip_quotes(cmd):
    cmd = re.sub(r\"'[^']*'\", \"''\", cmd)
    cmd = re.sub(r'\"[^\"]*\"', '\"\"', cmd)
    return cmd

# T-1427: Strip bash comments (# through end-of-line) so that commented-out
# references to Tier 0 phrases in diagnostic/exploratory commands don't
# trigger false-positive blocks. Bash treats # as a comment only at the
# start of a token — i.e. at line start or preceded by whitespace. An
# unescaped # after non-whitespace (like URL fragments) is NOT a comment.
# Apply AFTER strip_quotes so # inside quoted strings is already neutralized.
def strip_comments(cmd):
    return re.sub(r'(^|\s)#[^\n]*', r'\1', cmd)

command_stripped = strip_heredocs(command)
command_stripped = strip_quotes(command_stripped)
command_stripped = strip_comments(command_stripped)

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

    # === Hook/enforcement bypass ===
    (r'\bgit\b[^;|&]*--no-verify\b',
     'HOOK BYPASS: --no-verify skips ALL git hooks (task ref, inception gate, audit)'),

    # === Destructive file operations (B-003) ===
    (r'\bfind\b[^;|&]*-delete\b',
     'FIND DELETE: Recursively deletes matching files'),
    (r'\bdd\s+if=',
     'DD: Raw disk/device write — can overwrite filesystems'),
    (r'\bchmod\b[^;|&]*-[a-zA-Z]*R[^;|&]*\s+000\b',
     'CHMOD 000 RECURSIVE: Removes all permissions recursively'),
    (r'\bmkfs\b',
     'MKFS: Creates filesystem — destroys existing data on device'),
    (r'\bpkill\s+-9\b',
     'PKILL -9: Force-kills processes by name (SIGKILL)'),

    # === Infrastructure destructive ===
    (r'\bdocker\s+system\s+prune\b',
     'DOCKER PRUNE: Removes all unused containers, networks, images'),
    (r'\bkubectl\s+delete\s+(namespace|ns)\s',
     'K8S NAMESPACE DELETE: Removes namespace and all resources in it'),

    # === Framework governance bypass (T-510) ===
    (r'\bfw\s+task\s+update\b[^;|&]*--force\b',
     'FW FORCE: Bypasses sovereignty gate (R-033), AC verification (P-010), or verification gate (P-011)'),

    # === Inception decision gate (T-557) ===
    # GO/NO-GO decisions are authority, not initiative. Agent recommends, human decides.
    (r'\bfw\s+inception\s+decide\b',
     'INCEPTION DECISION: GO/NO-GO decisions require human authority. Present your recommendation and rationale, then ask the human to run: fw inception decide T-XXX go|no-go --rationale \"...\"'),
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

# Compute command hash for approval matching.
# T-1500: normalize whitespace before hashing so an agent regenerating the
# blocked command for retry (with reflowed args, extra spaces, trailing
# newline differences) still matches the approval. Single-use semantics
# (rm -f on consume) bound the marginal collision risk; the human approved
# the human-readable risk description, not a byte-exact command.
COMMAND_NORMALIZED=$(printf '%s' "$COMMAND" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')
COMMAND_HASH=$(printf '%s' "$COMMAND_NORMALIZED" | sha256sum | awk '{print $1}')

# ── T-1508: Idempotency sentinel — short-circuit duplicate hook firings ──
# When the same hook is registered in both .claude/settings.json (project) and
# ~/.claude/settings.json (user), each Bash call fires every hook twice. The
# first invocation consumes the approval (rm -f $APPROVAL_FILE) and exits 0;
# without this sentinel, the second invocation finds no approval and BLOCKS,
# defeating the gate entirely. T-1506 RCA confirmed live (see L-XXX).
#
# Mechanism: on consume, write ${APPROVAL_FILE}.consumed (hash + timestamp).
# Before any block path runs, check if a recent (<5s) sentinel matches this
# command's hash. If so, allow without re-blocking. 5s is short enough that
# the next legitimate destructive command in this terminal still requires a
# fresh approval, but long enough to absorb every plausible duplicate-fire.
CONSUMED_FILE="${APPROVAL_FILE}.consumed"
if [ -f "$CONSUMED_FILE" ]; then
    CONSUMED_HASH=$(awk '{print $1}' "$CONSUMED_FILE" 2>/dev/null)
    CONSUMED_TIME=$(awk '{print $2}' "$CONSUMED_FILE" 2>/dev/null)
    CURRENT_TIME=$(date +%s)
    if [ "$CONSUMED_HASH" = "$COMMAND_HASH" ]; then
        AGE=$((CURRENT_TIME - ${CONSUMED_TIME:-0}))
        if [ "$AGE" -lt 5 ]; then
            # Same command, just consumed by a sibling hook fire — allow without re-blocking.
            exit 0
        fi
    fi
    # Stale sentinel — clean up so we don't accumulate cruft.
    if [ -n "${CONSUMED_TIME:-}" ] && [ "$((${CURRENT_TIME:-$(date +%s)} - CONSUMED_TIME))" -ge 5 ]; then
        rm -f "$CONSUMED_FILE"
    fi
fi

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
            # T-1508: write idempotency sentinel so duplicate hook firings
            # for the same command short-circuit instead of re-blocking.
            echo "$COMMAND_HASH $(date +%s)" > "$CONSUMED_FILE"

            # Log to bypass-log for audit trail (fire-and-forget)
            # Data passed via env vars to avoid shell interpolation into source code (T-595)
            T0_LOG_FILE="$PROJECT_ROOT/.context/bypass-log.yaml" \
            T0_DESCRIPTION="$DESCRIPTION" \
            T0_COMMAND_PREVIEW="${COMMAND:0:120}" \
            T0_COMMAND_HASH="$COMMAND_HASH" \
            python3 -c "
import yaml, datetime, os

log_file = os.environ['T0_LOG_FILE']
entry = {
    'timestamp': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'tier': 0,
    'risk': os.environ['T0_DESCRIPTION'],
    'command_preview': os.environ['T0_COMMAND_PREVIEW'],
    'command_hash': os.environ['T0_COMMAND_HASH'],
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

# ── Check for Watchtower approval in .context/approvals/ (T-612) ──
APPROVAL_DIR="$PROJECT_ROOT/.context/approvals"
WATCHTOWER_TTL="${TIER0_WATCHTOWER_TTL:-3600}"  # Default 1 hour
RESOLVED_FILE="$APPROVAL_DIR/resolved-${COMMAND_HASH:0:12}.yaml"

if [ -f "$RESOLVED_FILE" ]; then
    WT_RESULT=$(T0_RESOLVED="$RESOLVED_FILE" T0_TTL="$WATCHTOWER_TTL" T0_HASH="$COMMAND_HASH" python3 -c "
import yaml, time, os, sys

resolved_file = os.environ['T0_RESOLVED']
ttl = int(os.environ['T0_TTL'])
expected_hash = os.environ['T0_HASH']

try:
    with open(resolved_file) as f:
        data = yaml.safe_load(f) or {}
except:
    print('SKIP')
    sys.exit(0)

status = data.get('status', '')
full_hash = data.get('command_hash', '')

if status != 'approved' or full_hash != expected_hash:
    print('SKIP')
    sys.exit(0)

# Check TTL from response timestamp
resp = data.get('response', {})
ts = resp.get('responded_at', '') or data.get('timestamp', '')
if not ts:
    print('SKIP')
    sys.exit(0)

from datetime import datetime, timezone
try:
    dt = datetime.fromisoformat(ts.replace('Z', '+00:00'))
    age = time.time() - dt.timestamp()
    if age > ttl:
        print('EXPIRED')
    else:
        print('APPROVED')
except:
    print('SKIP')
" 2>/dev/null)

    if [ "$WT_RESULT" = "APPROVED" ]; then
        # Valid Watchtower approval — consume it and allow
        # Mark as consumed (single-use, keep file for audit trail)
        T0_RESOLVED="$RESOLVED_FILE" python3 -c "
import yaml, os
from datetime import datetime, timezone

f = os.environ['T0_RESOLVED']
with open(f) as fh:
    data = yaml.safe_load(fh) or {}
data['status'] = 'consumed'
data.setdefault('response', {})['consumed_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
with open(f, 'w') as fh:
    yaml.dump(data, fh, default_flow_style=False, sort_keys=False)
" 2>/dev/null

        # Log to bypass-log for audit trail (fire-and-forget)
        T0_LOG_FILE="$PROJECT_ROOT/.context/bypass-log.yaml" \
        T0_DESCRIPTION="$DESCRIPTION" \
        T0_COMMAND_PREVIEW="${COMMAND:0:120}" \
        T0_COMMAND_HASH="$COMMAND_HASH" \
        python3 -c "
import yaml, datetime, os

log_file = os.environ['T0_LOG_FILE']
entry = {
    'timestamp': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'tier': 0,
    'risk': os.environ['T0_DESCRIPTION'],
    'command_preview': os.environ['T0_COMMAND_PREVIEW'],
    'command_hash': os.environ['T0_COMMAND_HASH'],
    'authorized_by': 'human',
    'mechanism': 'watchtower',
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

# ── Check for prior rejection feedback (T-641) ──
REJECTION_FEEDBACK=""
if [ -f "$RESOLVED_FILE" ]; then
    REJECTION_FEEDBACK=$(T0_RESOLVED="$RESOLVED_FILE" T0_HASH="$COMMAND_HASH" python3 -c "
import yaml, os, sys

resolved_file = os.environ['T0_RESOLVED']
expected_hash = os.environ['T0_HASH']

try:
    with open(resolved_file) as f:
        data = yaml.safe_load(f) or {}
except:
    sys.exit(0)

if data.get('status') != 'rejected' or data.get('command_hash', '') != expected_hash:
    sys.exit(0)

resp = data.get('response', {})
feedback = resp.get('feedback', '')
if feedback:
    print(feedback)
" 2>/dev/null)
fi

# ── Block with explanation ──
# Detect Watchtower URL via shared helper (T-1154, T-1156)
WT_URL=$(_watchtower_url 2>/dev/null || echo "http://localhost:3000")

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
if [ -n "$REJECTION_FEEDBACK" ]; then
echo "  Previous rejection feedback:" >&2
echo "    $REJECTION_FEEDBACK" >&2
echo "" >&2
fi
echo "  Approve in Watchtower:" >&2
echo "    ${WT_URL}/approvals" >&2
echo "" >&2
echo "  Or via CLI:" >&2
echo "    $(_emit_user_command "tier0 approve")" >&2
echo "" >&2
echo "  Policy: 011-EnforcementConfig.md §Tier 0" >&2
echo "══════════════════════════════════════════════════════════" >&2
echo "" >&2

# Write the pending command hash so 'fw tier0 approve' can pick it up
echo "$COMMAND_HASH $(date +%s) PENDING" > "${APPROVAL_FILE}.pending"

# Also write a human-readable YAML for Watchtower approval surface (T-611)
APPROVAL_DIR="${APPROVAL_DIR:-$PROJECT_ROOT/.context/approvals}"
mkdir -p "$APPROVAL_DIR" 2>/dev/null
APPROVAL_YAML="$APPROVAL_DIR/pending-${COMMAND_HASH:0:12}.yaml"
T0_RISK="$DESCRIPTION" T0_CMD="$COMMAND" T0_HASH="$COMMAND_HASH" python3 -c "
import yaml, sys, os
data = {
    'timestamp': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'type': 'tier0',
    'risk': os.environ.get('T0_RISK', ''),
    'command_preview': os.environ.get('T0_CMD', '')[:200],
    'command_hash': os.environ.get('T0_HASH', ''),
    'status': 'pending',
}
with open(sys.argv[1], 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
" "$APPROVAL_YAML" 2>/dev/null || true

# Push notification for Tier 0 block (T-709)
if [ -f "$FRAMEWORK_ROOT/lib/notify.sh" ]; then
    source "$FRAMEWORK_ROOT/lib/notify.sh"
    fw_notify "Tier 0 Approval Needed" "$DESCRIPTION — Approve: ${WT_URL}/approvals" "task_blocked" "framework"
fi

exit 2
