#!/bin/bash
# Post-Compaction Resume Hook — Reinject structured context after compaction
# Fires on SessionStart with matcher "compact".
# Outputs additionalContext JSON so Claude has framework state immediately.
#
# Part of: T-111 (Autonomous compact-resume lifecycle)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$FRAMEWORK_ROOT}"
LATEST="$PROJECT_ROOT/.context/handovers/LATEST.md"
FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"

# Build context string
CONTEXT=""

# Handover (primary recovery document)
if [ -f "$LATEST" ]; then
    # Extract key sections (strip heading lines, keep content lean)
    WHERE=$(sed -n '/^## Where We Are/,/^## /p' "$LATEST" | grep -v "^## " | head -10)
    WIP=$(sed -n '/^## Work in Progress/,/^## /p' "$LATEST" | grep -v "^## " | head -20)
    SUGGESTED=$(sed -n '/^## Suggested First Action/,/^## /p' "$LATEST" | grep -v "^## " | head -5)
    GOTCHAS=$(sed -n '/^## Gotchas/,/^## /p' "$LATEST" | grep -v "^## " | head -10)

    CONTEXT="# Post-Compaction Context Recovery (automatic)

## Where We Are
${WHERE}

## Work in Progress
${WIP}

## Suggested Action
${SUGGESTED}

## Gotchas
${GOTCHAS}
"
fi

# Current focus
if [ -f "$FOCUS_FILE" ]; then
    FOCUS_TASK=$(grep "^current_task:" "$FOCUS_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' ')
    if [ -n "$FOCUS_TASK" ]; then
        CONTEXT="${CONTEXT}
## Current Focus: ${FOCUS_TASK}
"
    fi
fi

# Active tasks summary
TASK_SUMMARY=""
for f in "$PROJECT_ROOT/.tasks/active"/*.md; do
    [ -f "$f" ] || continue
    tid=$(grep "^id:" "$f" | head -1 | sed 's/id:[[:space:]]*//')
    tname=$(grep "^name:" "$f" | head -1 | sed 's/name:[[:space:]]*//')
    tstatus=$(grep "^status:" "$f" | head -1 | sed 's/status:[[:space:]]*//')
    thoriz=$(grep "^horizon:" "$f" | head -1 | sed 's/horizon:[[:space:]]*//' || echo "now")
    TASK_SUMMARY="${TASK_SUMMARY}
- ${tid}: ${tname} (${tstatus}, horizon: ${thoriz})"
done

if [ -n "$TASK_SUMMARY" ]; then
    CONTEXT="${CONTEXT}
## Active Tasks
${TASK_SUMMARY}
"
fi

# Git state
BRANCH=$(git -C "$PROJECT_ROOT" branch --show-current 2>/dev/null)
LAST_COMMIT=$(git -C "$PROJECT_ROOT" log -1 --pretty=format:"%h %s" 2>/dev/null)
UNCOMMITTED=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

CONTEXT="${CONTEXT}
## Git State
- Branch: ${BRANCH}
- Last commit: ${LAST_COMMIT}
- Uncommitted: ${UNCOMMITTED} files

---
*This context was auto-injected by the post-compaction resume hook (T-111). Run \`fw resume status\` for full details.*
"

# Output JSON with additionalContext for Claude Code
python3 -c "
import json, sys
context = sys.stdin.read()
output = {
    'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context
    }
}
print(json.dumps(output))
" <<< "$CONTEXT"
