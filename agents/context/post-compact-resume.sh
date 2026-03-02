#!/bin/bash
# Session Resume Hook — Reinject structured context on session recovery
# Fires on SessionStart with matchers "compact" and "resume" (T-188).
# Outputs additionalContext JSON so Claude has framework state immediately.
#
# Triggers:
#   - After /compact (manual compaction recovery)
#   - After claude -c (session continuation, including auto-restart via T-179)
#
# Part of: T-111 (compact-resume), T-179/T-188 (auto-restart)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Resolve PROJECT_ROOT from git toplevel — framework/ is typically a subdirectory,
# not the project root. Fall back to FRAMEWORK_ROOT for standalone installs.
PROJECT_ROOT="${PROJECT_ROOT:-$(git -C "$FRAMEWORK_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "$FRAMEWORK_ROOT")}"
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
"

# Fabric topology overview (T-213 — spatial memory injection)
if [ -f "$PROJECT_ROOT/.fabric/subsystems.yaml" ]; then
    FABRIC_OVERVIEW=$("$PROJECT_ROOT/agents/fabric/fabric.sh" overview 2>/dev/null)
    if [ -n "$FABRIC_OVERVIEW" ]; then
        CONTEXT="${CONTEXT}

${FABRIC_OVERVIEW}"
    fi
fi

# Discovery findings (T-241 — surface WARN/FAIL discoveries at session start)
DISC_FILE="$PROJECT_ROOT/.context/audits/discoveries/LATEST.yaml"
if [ -f "$DISC_FILE" ]; then
    DISC_SUMMARY=$(python3 -c "
import yaml, sys
with open('$DISC_FILE') as f:
    data = yaml.safe_load(f)
if not data or 'findings' not in data:
    sys.exit(0)
items = [f for f in data['findings'] if f.get('level') in ('WARN', 'FAIL')]
if not items:
    sys.exit(0)
for f in items:
    print(f\"- [{f['level']}] {f['check']}\")
" 2>/dev/null)
    if [ -n "$DISC_SUMMARY" ]; then
        CONTEXT="${CONTEXT}

## Discovery Findings (WARN/FAIL)
${DISC_SUMMARY}
"
    fi
fi

CONTEXT="${CONTEXT}

---
*This context was auto-injected by the session resume hook (T-111/T-188). Run \`fw resume status\` for full details.*
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
