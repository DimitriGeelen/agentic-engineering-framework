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
source "$FRAMEWORK_ROOT/lib/paths.sh"
FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Extract file path from tool input (supports file_path and notebook_path for NotebookEdit)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    ti = data.get('tool_input', {})
    print(ti.get('file_path', '') or ti.get('notebook_path', ''))
except:
    print('')
" 2>/dev/null)

# B-005 (T-229): Protect hook enforcement config from agent modification.
# .claude/settings.json controls which hooks run — modifying it can disable all enforcement.
# Block this specifically BEFORE the general exempt-path check.
case "$FILE_PATH" in
    */settings.json)
        # Only block if it's the Claude Code settings file
        if echo "$FILE_PATH" | grep -q '\.claude/settings\.json$'; then
            echo "" >&2
            echo "BLOCKED: Cannot modify .claude/settings.json — this controls enforcement hooks." >&2
            echo "" >&2
            echo "Modifying this file could disable task gates, Tier 0 checks, and budget enforcement." >&2
            echo "Changes to hook configuration require human review." >&2
            echo "" >&2
            echo "Policy: B-005 (Enforcement Config Protection)" >&2
            exit 2
        fi
        ;;
esac

# Exempt paths — framework operations that are part of task management itself
# Anchored to PROJECT_ROOT to prevent matching arbitrary paths (e.g., /root/.claude/)
case "$FILE_PATH" in
    "$PROJECT_ROOT"/.context/*|"$PROJECT_ROOT"/.tasks/*|"$PROJECT_ROOT"/.claude/*|"$PROJECT_ROOT"/.git/*)
        exit 0
        ;;
esac

# If no .context/ directory exists yet (fresh project), allow — bootstrap case
if [ ! -d "$PROJECT_ROOT/.context/working" ]; then
    exit 0
fi

# If no focus file exists: block if project is initialized, allow if bootstrap (T-002)
if [ ! -f "$FOCUS_FILE" ]; then
    if [ -f "$PROJECT_ROOT/.framework.yaml" ]; then
        # Project is initialized but governance not active — block
        echo "BLOCKED: Project initialized but session not active. Run 'fw context init' first." >&2
        exit 2
    fi
    # True bootstrap — no .framework.yaml yet, allow
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

# Verify task is actually active (not completed/archived) — G-013
ACTIVE_FILE=$(find_task_file "$CURRENT_TASK" active)
if [ -z "$ACTIVE_FILE" ]; then
    echo "" >&2
    echo "BLOCKED: Task $CURRENT_TASK is not active (may be completed or missing)." >&2
    echo "" >&2
    echo "To unblock:" >&2
    echo "  fw work-on T-XXX   (resume an active task)" >&2
    echo "  fw work-on 'name'  (create a new task)" >&2
    echo "" >&2
    echo "Attempting to modify: $FILE_PATH" >&2
    echo "Policy: P-002 (Structural Enforcement Over Agent Discipline)" >&2
    exit 2
fi

# --- Status validation (T-354) ---
# Task file exists in active/ but may be captured (not started) or work-completed
# (partial-complete). Only started-work and issues are workable statuses.
TASK_STATUS=$(grep "^status:" "$ACTIVE_FILE" | head -1 | sed 's/status:[[:space:]]*//')
case "$TASK_STATUS" in
    started-work|issues)
        # Workable statuses — allow
        ;;
    captured)
        echo "" >&2
        echo "BLOCKED: Task $CURRENT_TASK has status 'captured' (work not started)." >&2
        echo "" >&2
        echo "To unblock:" >&2
        echo "  fw work-on $CURRENT_TASK   (sets status to started-work)" >&2
        echo "" >&2
        echo "Attempting to modify: $FILE_PATH" >&2
        echo "Policy: P-002 (Task must be started before modifying files)" >&2
        exit 2
        ;;
    work-completed)
        echo "" >&2
        echo "BLOCKED: Task $CURRENT_TASK has status 'work-completed'." >&2
        echo "" >&2
        echo "To unblock:" >&2
        echo "  fw work-on T-XXX   (resume another task)" >&2
        echo "  fw work-on 'name'  (create a new task)" >&2
        echo "" >&2
        echo "Attempting to modify: $FILE_PATH" >&2
        echo "Policy: P-002 (Cannot modify files under a completed task)" >&2
        exit 2
        ;;
    "")
        # Legacy task without status field — warn but allow
        echo "NOTE: Task $CURRENT_TASK has no status field in task file." >&2
        ;;
esac

# --- Inception awareness ---
# If the active task is inception type with no decision, warn (don't block)
# ACTIVE_FILE already resolved above
if [ -n "$ACTIVE_FILE" ] && grep -q "^workflow_type: inception" "$ACTIVE_FILE" 2>/dev/null; then
    if ! grep -q '^\*\*Decision\*\*: \(GO\|NO-GO\|DEFER\)' "$ACTIVE_FILE" 2>/dev/null; then
        echo "NOTE: Active task $CURRENT_TASK is inception (no decision yet). Ensure you are doing exploration, not building." >&2
    fi
fi

# --- Fabric awareness advisory (T-244) ---
# If the file is a registered fabric component with dependents, show a note.
# Advisory only — never blocks. Runs only for non-exempt paths.
if [ -n "$FILE_PATH" ] && [ -d "$FRAMEWORK_ROOT/.fabric/components" ]; then
    # Resolve relative path
    REL_PATH=$(realpath --relative-to="$PROJECT_ROOT" "$FILE_PATH" 2>/dev/null || echo "$FILE_PATH")
    # Quick count: how many other cards reference this file?
    DEP_COUNT=$(python3 -c "
import os, glob, re
root = '$PROJECT_ROOT'
rel = '$REL_PATH'
cards_dir = os.path.join(root, '.fabric', 'components')
# Find this file's card to get its id/name
comp_id = comp_name = ''
for card in glob.glob(os.path.join(cards_dir, '*.yaml')):
    with open(card) as f:
        text = f.read()
    if f'location: {rel}' in text or f'id: {rel}' in text:
        for line in text.split('\n'):
            if line.startswith('id: '): comp_id = line[4:].strip()
            if line.startswith('name: '): comp_name = line[6:].strip()
        break
if not comp_id:
    print(0)
else:
    # Count cards that reference this component
    count = 0
    patterns = [comp_id, comp_name, rel]
    for card in glob.glob(os.path.join(cards_dir, '*.yaml')):
        with open(card) as f:
            text = f.read()
        if f'id: {comp_id}' in text:
            continue  # skip self
        if any(f'target: {p}' in text or f'target: \"{p}\"' in text for p in patterns if p):
            count += 1
    print(count)
" 2>/dev/null || echo 0)
    if [ "$DEP_COUNT" -gt 0 ]; then
        echo "FABRIC: $REL_PATH has $DEP_COUNT downstream dependent(s). Consider: fw fabric blast-radius after commit." >&2
    fi
fi

# Active task exists — allow
exit 0
