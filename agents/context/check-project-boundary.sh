#!/bin/bash
# Project Boundary Enforcement Hook — PreToolUse gate for Write/Edit/Bash
# Blocks file modifications and commands targeting paths outside PROJECT_ROOT.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# For Write/Edit: extracts file_path, blocks if outside PROJECT_ROOT.
# For Bash: detects cd+write patterns targeting other projects.
#
# Allowed exceptions:
#   /tmp/**                — Agent dispatch working files
#   /root/.claude/**       — Claude Code memory/settings
#   PROJECT_ROOT/**        — Obviously allowed
#
# Origin: T-559 — Agent created 6 tasks on another project (T-549 violation)
# Part of: Agentic Engineering Framework (P-002: Structural Enforcement)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-project-boundary"

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

# ── Write/Edit gate ──
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "NotebookEdit" ]; then
    FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {})
    print(ti.get('file_path', '') or ti.get('notebook_path', ''))
except:
    print('')
" 2>/dev/null)

    # No path — allow (defensive)
    [ -z "$FILE_PATH" ] && exit 0

    # Resolve to absolute path
    RESOLVED=$(realpath -m "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")

    # Allowed zones
    case "$RESOLVED" in
        "$PROJECT_ROOT"/*)
            exit 0
            ;;
        /tmp/*)
            exit 0
            ;;
        /root/.claude/*)
            exit 0
            ;;
    esac

    # Everything else: BLOCK
    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  PROJECT BOUNDARY BLOCK — Write Outside Project Root" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Target:       $FILE_PATH" >&2
    echo "  Project root: $PROJECT_ROOT" >&2
    echo "" >&2
    echo "  Write/Edit operations are restricted to the current project." >&2
    echo "  This prevents accidental modification of other projects," >&2
    echo "  system files, or resources outside your workspace." >&2
    echo "" >&2
    echo "  Allowed zones:" >&2
    echo "    - $PROJECT_ROOT/**  (project files)" >&2
    echo "    - /tmp/**           (agent dispatch scratch)" >&2
    echo "    - /root/.claude/**  (Claude Code config)" >&2
    echo "" >&2
    echo "  For cross-project reads, use TermLink dispatch:" >&2
    echo "" >&2
    echo "    fw termlink dispatch --name read --project /opt/other \\" >&2
    echo "      --prompt 'cat README.md and return its contents'" >&2
    echo "" >&2
    echo "  Policy: T-559 (Project Boundary Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# ── Bash gate ──
if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

    # No command — allow (defensive)
    [ -z "$COMMAND" ] && exit 0

    # Quick pre-filter: if no absolute path reference, skip Python analysis
    if ! echo "$COMMAND" | grep -qE '(cd\s+/|/opt/|/home/|>+\s*/|tee\s+/|\.agentic-framework/bin/fw)'; then
        exit 0
    fi

    # TermLink exception: commands routed through termlink interact/pty/dispatch
    # execute in a separate process, not in our shell. The cd inside the
    # quoted argument targets the TermLink session, not the framework session.
    # T-679: Boundary hook was blocking all TermLink cross-project operations.
    # T-1075: Also match TermLink commands inside loops/pipes (not just at start).
    #   e.g., `for n in ...; do termlink pty inject ... "cd /opt/$n && ..."`
    if echo "$COMMAND" | grep -qE '(^|\s|;|&&|\|)(termlink|bin/fw termlink|fw termlink)\s'; then
        exit 0
    fi

    # Detailed analysis: detect cd to another project + write operations
    export _BOUNDARY_CMD="$COMMAND"
    MATCH_RESULT=$(python3 << 'PYEOF'
import re, sys, os

command = os.environ.get('_BOUNDARY_CMD', '')
project_root = os.environ.get('PROJECT_ROOT', '')

# Normalize project root (remove trailing slash)
project_root = project_root.rstrip('/')

if not project_root:
    print('SAFE')
    sys.exit(0)

# Pattern 1: cd to absolute path outside project root
cd_pattern = re.compile(r'cd\s+(/[^\s;&|]+)')
matches = cd_pattern.findall(command)

for target_dir in matches:
    target = target_dir.rstrip('/')
    if not target.startswith(project_root + '/') and target != project_root:
        # Allow cd to safe zones
        if target.startswith('/tmp') or target.startswith('/root/.claude'):
            continue
        print(f'BLOCKED|cd to {target} (outside project root {project_root})')
        sys.exit(0)

# Pattern 2: Direct invocation of fw/agentic-framework tools on another path
fw_pattern = re.compile(r'(/[^\s]+/)\.agentic-framework/bin/fw\b')
for fw_path in fw_pattern.findall(command):
    fw_dir = fw_path.rstrip('/')
    if not fw_dir.startswith(project_root + '/') and fw_dir != project_root:
        print(f'BLOCKED|Direct fw invocation on {fw_dir} (outside project root)')
        sys.exit(0)

# Pattern 3: File write operations targeting absolute paths outside project
write_ops = re.compile(r'(?:>>?\s*|tee\s+)(/[^\s;&|]+)')
for target_file in write_ops.findall(command):
    if target_file.startswith(('/tmp/', '/root/.claude/', '/dev/')):
        continue
    if not target_file.startswith(project_root + '/'):
        print(f'BLOCKED|File write to {target_file} (outside project root)')
        sys.exit(0)

print('SAFE')
PYEOF
)

    if [ -z "$MATCH_RESULT" ] || [ "$MATCH_RESULT" = "SAFE" ]; then
        exit 0
    fi

    DESCRIPTION="${MATCH_RESULT#BLOCKED|}"

    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  PROJECT BOUNDARY BLOCK — Command Targets Another Project" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Reason: $DESCRIPTION" >&2
    echo "  Command: ${COMMAND:0:150}" >&2
    echo "" >&2
    echo "  Bash commands must operate within the current project." >&2
    echo "" >&2
    echo "  For legitimate cross-project work, use TermLink dispatch which" >&2
    echo "  runs the command in the target project's own session context:" >&2
    echo "" >&2
    echo "    fw termlink dispatch --name work --project /opt/other \\" >&2
    echo "      --prompt 'describe the work for the target project'" >&2
    echo "" >&2
    echo "  Or spawn an interactive TermLink session rooted in the target:" >&2
    echo "" >&2
    echo "    termlink spawn --name work --backend background --shell \\" >&2
    echo "      --wait --tags 'task:T-XXX' --cwd /opt/other" >&2
    echo "" >&2
    echo "  Neither path crosses the boundary of *this* session; each" >&2
    echo "  target project enforces its own governance in its own process." >&2
    echo "" >&2
    echo "  Project root: $PROJECT_ROOT" >&2
    echo "" >&2
    echo "  Policy: T-559 (Project Boundary Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# Not a Write/Edit/Bash tool — allow
exit 0
