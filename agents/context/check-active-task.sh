#!/bin/bash
# Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools
# Blocks file modifications when no active task is set in focus.yaml.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Receives JSON on stdin with tool_name and tool_input.file_path.
#
# Exempt paths (framework operations that don't need task context):
#   .context/   — Context fabric management
#   .tasks/     — Task creation/updates
#   .claude/    — Claude Code settings
#
# Part of: Agentic Engineering Framework (P-002: Structural Enforcement)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Extract file path from tool input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null)

# Exempt paths — framework operations that are part of task management itself
case "$FILE_PATH" in
    */.context/*|*/.tasks/*|*/.claude/*|*/.git/*)
        exit 0
        ;;
esac

# If no .context/ directory exists yet (fresh project), allow — bootstrap case
if [ ! -d "$PROJECT_ROOT/.context/working" ]; then
    exit 0
fi

# If no focus file exists, allow but warn (context not initialized)
if [ ! -f "$FOCUS_FILE" ]; then
    echo "Note: Context not initialized. Run 'fw context init' for task tracking." >&2
    exit 0
fi

# Read current task from focus.yaml
CURRENT_TASK=$(python3 -c "
import yaml, sys
try:
    with open('$FOCUS_FILE') as f:
        data = yaml.safe_load(f)
    task = data.get('current_task', '') if data else ''
    print(task if task and task != 'null' else '')
except:
    print('')
" 2>/dev/null)

if [ -z "$CURRENT_TASK" ]; then
    echo "" >&2
    echo "BLOCKED: No active task. Framework rule: nothing gets done without a task." >&2
    echo "" >&2
    echo "To unblock:" >&2
    echo "  1. Create a task:  fw task create --name '...' --type build --start" >&2
    echo "  2. Set focus:      fw context focus T-XXX" >&2
    echo "" >&2
    echo "Attempting to modify: $FILE_PATH" >&2
    echo "Policy: P-002 (Structural Enforcement Over Agent Discipline)" >&2
    exit 2
fi

# --- Inception awareness ---
# If the active task is inception type with no decision, warn (don't block)
TASK_FILE=$(find "$PROJECT_ROOT/.tasks/active" -name "${CURRENT_TASK}-*.md" -type f 2>/dev/null | head -1)
if [ -n "$TASK_FILE" ] && grep -q "^workflow_type: inception" "$TASK_FILE" 2>/dev/null; then
    if ! grep -q '^\*\*Decision\*\*: \(GO\|NO-GO\|DEFER\)' "$TASK_FILE" 2>/dev/null; then
        echo "NOTE: Active task $CURRENT_TASK is inception (no decision yet). Ensure you are doing exploration, not building." >&2
    fi
fi

# Active task exists — allow
exit 0
