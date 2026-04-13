#!/bin/bash
# Task-First Enforcement Hook — PreToolUse gate for Write/Edit/Bash tools
# Blocks file modifications when no active task is set in focus.yaml.
#
# Exit codes (Claude Code PreToolUse semantics):
#   0 — Allow tool execution
#   2 — Block tool execution (stderr shown to agent)
#
# Receives JSON on stdin with tool_name and tool_input.
# For Write/Edit: checks tool_input.file_path
# For Bash: checks tool_input.command against safe-command allowlist (T-650)
#
# Exempt paths (framework operations that don't need task context):
#   .context/   — Context fabric management
#   .tasks/     — Task creation/updates
#   .claude/    — Claude Code settings
#
# Part of: Agentic Engineering Framework (P-002: Structural Enforcement)

set -uo pipefail

# --- FW_SAFE_MODE escape hatch (T-650) ---
# Disables task gate only. Tier 0 and boundary check remain active.
if [ "${FW_SAFE_MODE:-0}" = "1" ]; then
    echo "SAFE MODE: Task gate bypassed (FW_SAFE_MODE=1)" >&2
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$FRAMEWORK_ROOT/lib/paths.sh"
source "$FRAMEWORK_ROOT/lib/config.sh"
fw_hook_crash_trap "check-active-task"
FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"

# Read stdin (JSON from Claude Code)
INPUT=$(cat)

# Extract tool name and inputs
TOOL_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_name', ''))
except:
    print('')
" 2>/dev/null)

# --- Bash tool: safe-command fast path (T-650) ---
if [ "$TOOL_NAME" = "Bash" ]; then
    BASH_CMD=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('command', ''))
except:
    print('')
" 2>/dev/null)

    # fw hook commands are always allowed (hooks calling hooks)
    case "$BASH_CMD" in
        "fw hook "*|"bin/fw hook "*)
            exit 0
            ;;
    esac

    # Source safe-command allowlist
    source "$SCRIPT_DIR/lib/safe-commands.sh" 2>/dev/null || true

    # Check write patterns FIRST — even "safe" commands with redirects are writes
    if type has_bash_write_pattern &>/dev/null && has_bash_write_pattern "$BASH_CMD"; then
        # Command has write patterns — fall through to active-task check
        :
    elif type is_bash_safe_command &>/dev/null && is_bash_safe_command "$BASH_CMD"; then
        # Safe command with no write patterns — allow without task
        exit 0
    fi

    # Non-safe or write-pattern Bash commands: fall through to active-task check.
    # FILE_PATH stays empty for Bash — exempt-path check won't match,
    # so we go straight to the task-exists check.
fi

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
        echo "BLOCKED: Project initialized but session not active. Run '$(_emit_user_command "context init")' first." >&2
        exit 2
    fi
    # True bootstrap — no .framework.yaml yet, allow
    echo "Note: Context not initialized. Run '$(_emit_user_command "context init")' for task tracking." >&2
    exit 0
fi

# Read current task AND session stamp from focus.yaml
read -r CURRENT_TASK FOCUS_SESSION < <(python3 -c "
import yaml, sys
try:
    with open('$FOCUS_FILE') as f:
        data = yaml.safe_load(f)
    if not data:
        print(' ')
    else:
        task = data.get('current_task', '') or ''
        if task == 'null': task = ''
        session = data.get('focus_session', '') or ''
        print(f'{task} {session}')
except:
    print(' ')
" 2>/dev/null)

# Read current session ID for comparison
CURRENT_SESSION=""
SESSION_FILE="$PROJECT_ROOT/.context/working/session.yaml"
if [ -f "$SESSION_FILE" ]; then
    CURRENT_SESSION=$(grep "^session_id:" "$SESSION_FILE" 2>/dev/null | head -1 | awk '{print $2}')
fi

if [ -z "$CURRENT_TASK" ]; then
    echo "" >&2
    echo "BLOCKED: No active task. Framework rule: nothing gets done without a task." >&2
    echo "" >&2
    echo "To unblock:" >&2
    echo "  1. Create a task:  $(_fw_cmd) task create --name '...' --type build --start" >&2
    echo "  2. Set focus:      $(_fw_cmd) context focus T-XXX" >&2
    echo "" >&2
    echo "Attempting to modify: $FILE_PATH" >&2
    echo "Policy: P-002 (Structural Enforcement Over Agent Discipline)" >&2
    exit 2
fi

# --- Session stamp validation (T-560) ---
# If focus was set in a PREVIOUS session, block and advise.
# This prevents stale focus from granting a free pass to new sessions.
if [ -n "$CURRENT_SESSION" ] && [ -n "$FOCUS_SESSION" ] && [ "$FOCUS_SESSION" != "$CURRENT_SESSION" ]; then
    # Look up task name for advisory
    STALE_TASK_NAME=""
    STALE_FILE=$(find_task_file "$CURRENT_TASK" active 2>/dev/null)
    if [ -n "$STALE_FILE" ]; then
        STALE_TASK_NAME=$(grep "^name:" "$STALE_FILE" 2>/dev/null | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
    fi

    echo "" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "  STALE FOCUS — Task From Previous Session" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    echo "  Previous task: $CURRENT_TASK" >&2
    [ -n "$STALE_TASK_NAME" ] && echo "  Name:          $STALE_TASK_NAME" >&2
    echo "  Set in session: $FOCUS_SESSION" >&2
    echo "  Current session: $CURRENT_SESSION" >&2
    echo "" >&2
    echo "  Focus was set in a previous session. To continue this task:" >&2
    echo "    $(_fw_cmd) work-on $CURRENT_TASK" >&2
    echo "" >&2
    echo "  To start different work:" >&2
    echo "    $(_fw_cmd) work-on 'New task name' --type build" >&2
    echo "" >&2
    echo "  Attempting to modify: $FILE_PATH" >&2
    echo "  Policy: T-560 (Session-Stamped Focus Enforcement)" >&2
    echo "══════════════════════════════════════════════════════════" >&2
    echo "" >&2
    exit 2
fi

# Verify task is actually active (not completed/archived) — G-013
ACTIVE_FILE=$(find_task_file "$CURRENT_TASK" active)
if [ -z "$ACTIVE_FILE" ]; then
    echo "" >&2
    echo "BLOCKED: Task $CURRENT_TASK is not active (may be completed or missing)." >&2
    echo "" >&2
    echo "To unblock:" >&2
    echo "  $(_fw_cmd) work-on T-XXX   (resume an active task)" >&2
    echo "  $(_fw_cmd) work-on 'name'  (create a new task)" >&2
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
        echo "  $(_fw_cmd) work-on $CURRENT_TASK   (sets status to started-work)" >&2
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
        echo "  $(_fw_cmd) work-on T-XXX   (resume another task)" >&2
        echo "  $(_fw_cmd) work-on 'name'  (create a new task)" >&2
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

# --- Onboarding gate (T-535) ---
# If incomplete onboarding tasks exist, only allow work on onboarding tasks.
# Detection: tasks with tags containing "onboarding" in .tasks/active/.
# Fast path: .context/working/.onboarding-complete marker means all done.
ONBOARDING_MARKER="$PROJECT_ROOT/.context/working/.onboarding-complete"
if [ ! -f "$ONBOARDING_MARKER" ]; then
    # Check if any active tasks have onboarding tag and are not completed
    INCOMPLETE_ONBOARDING=""
    for tf in "$PROJECT_ROOT"/.tasks/active/T-*.md; do
        [ -f "$tf" ] || continue
        if head -20 "$tf" | grep -q '^tags:.*onboarding' 2>/dev/null; then
            tf_status=$(grep "^status:" "$tf" | head -1 | sed 's/status:[[:space:]]*//')
            if [ "$tf_status" != "work-completed" ]; then
                tf_id=$(grep "^id:" "$tf" | head -1 | sed 's/id:[[:space:]]*//')
                tf_name=$(grep "^name:" "$tf" | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
                INCOMPLETE_ONBOARDING="${INCOMPLETE_ONBOARDING}  ${tf_id}: ${tf_name} (${tf_status})\n"
            fi
        fi
    done

    if [ -n "$INCOMPLETE_ONBOARDING" ]; then
        # Check if current task is an onboarding task
        CURRENT_IS_ONBOARDING=false
        if [ -n "$ACTIVE_FILE" ] && head -20 "$ACTIVE_FILE" | grep -q '^tags:.*onboarding' 2>/dev/null; then
            CURRENT_IS_ONBOARDING=true
        fi

        if [ "$CURRENT_IS_ONBOARDING" = false ]; then
            echo "" >&2
            echo "BLOCKED: Onboarding tasks incomplete. Complete setup before starting other work." >&2
            echo "" >&2
            echo "Remaining onboarding tasks:" >&2
            echo -e "$INCOMPLETE_ONBOARDING" >&2
            echo "To work on onboarding:" >&2
            echo "  $(_fw_cmd) work-on T-001" >&2
            echo "" >&2
            echo "To skip onboarding (not recommended):" >&2
            echo "  $(_fw_cmd) onboarding skip" >&2
            echo "" >&2
            echo "Attempting to modify: $FILE_PATH" >&2
            echo "Policy: T-532 (Onboarding Enforcement Gate)" >&2
            exit 2
        fi
    else
        # All onboarding tasks done (or none exist) — write marker for fast path
        mkdir -p "$(dirname "$ONBOARDING_MARKER")"
        echo "completed: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$ONBOARDING_MARKER"
    fi
fi

# --- Inception awareness ---
# If the active task is inception type with no decision, warn (don't block)
# ACTIVE_FILE already resolved above
if [ -n "$ACTIVE_FILE" ] && grep -q "^workflow_type: inception" "$ACTIVE_FILE" 2>/dev/null; then
    if ! grep -q '^\*\*Decision\*\*: \(GO\|NO-GO\|DEFER\)' "$ACTIVE_FILE" 2>/dev/null; then
        echo "NOTE: Active task $CURRENT_TASK is inception (no decision yet)." >&2
        echo "  Ensure you are doing exploration, not building." >&2
    fi
fi

# --- Build readiness gate (G-020, T-471) ---
# Build/refactor/test tasks must have real ACs before modifying source files.
# Placeholder ACs ([First criterion]) indicate the task was created from template
# but never scoped. This prevents building without acceptance criteria.
# Inception tasks have their own gate above; skip them here.
if [ -n "$ACTIVE_FILE" ]; then
    WORKFLOW_TYPE=$(grep "^workflow_type:" "$ACTIVE_FILE" 2>/dev/null | head -1 | sed 's/workflow_type:[[:space:]]*//')
    case "$WORKFLOW_TYPE" in
        build|refactor|test|decommission)
            AC_SECTION=$(sed -n '/^## Acceptance Criteria/,/^## [^A]/p' "$ACTIVE_FILE" 2>/dev/null | sed '$d')
            HAS_PLACEHOLDER=$(echo "$AC_SECTION" | grep -ciE '\[(First|Second|Third|Fourth|Fifth) criterion\]' 2>/dev/null || true)
            REAL_AC_COUNT=$(echo "$AC_SECTION" | grep -cE '^\s*-\s*\[[ x]\]' 2>/dev/null || true)
            if [ "${HAS_PLACEHOLDER:-0}" -gt 0 ] || [ "${REAL_AC_COUNT:-0}" -eq 0 ]; then
                echo "" >&2
                echo "BLOCKED: Task $CURRENT_TASK is a $WORKFLOW_TYPE task with placeholder/missing ACs." >&2
                echo "" >&2
                echo "Build tasks require real acceptance criteria before editing source files." >&2
                echo "This prevents unscoped building. (G-020: Scope-Aware Task Gate)" >&2
                echo "" >&2
                echo "To unblock:" >&2
                echo "  1. Edit the task file: replace [First criterion] with real ACs" >&2
                echo "  2. Or change to inception:" >&2
                echo "     $(_fw_cmd) task update $CURRENT_TASK --type inception" >&2
                echo "" >&2
                echo "Attempting to modify: $FILE_PATH" >&2
                echo "Policy: G-020 (Pickup message governance bypass prevention)" >&2
                exit 2
            fi
            ;;
    esac
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
        echo "FABRIC: $REL_PATH has $DEP_COUNT downstream dependent(s). Consider: $(_fw_cmd) fabric blast-radius after commit." >&2
    fi
fi

# Active task exists — allow
exit 0
