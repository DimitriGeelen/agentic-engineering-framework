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
source "$FRAMEWORK_ROOT/lib/paths.sh"
LATEST="$PROJECT_ROOT/.context/handovers/LATEST.md"
FOCUS_FILE="$PROJECT_ROOT/.context/working/focus.yaml"

# T-712/T-713: Clear ALL session-scoped volatile state on session recovery.
# These files are counters, caches, and flags that are valid only within a
# single session. Carrying them across compact/resume causes stale-state bugs:
# - .agent-dispatch-counter: old count blocks agent dispatch
# - .handover-cooldown: old cooldown prevents handover in new session
# - .loop-detect.json: old patterns cause false loop detection
VOLATILE_FILES=(
    .budget-gate-counter
    .agent-dispatch-counter
    .edit-counter
    .tool-counter
    .prev-token-reading
    .handover-cooldown
    .loop-detect.json
    .new-file-counter
    .approval-notified
)
for vf in "${VOLATILE_FILES[@]}"; do
    rm -f "$PROJECT_ROOT/.context/working/$vf" 2>/dev/null
done

# T-1087: Seed .budget-status with fresh {ok, 0, now} instead of deleting.
# Regression of T-145/T-271/T-712/T-713: plain rm leaves the fast path to
# fall through to slow path, which re-reads the resumed JSONL and picks up
# the pre-compact final usage entry as the "last usage" (claude -c continues
# writing to the same JSONL; the first post-compact assistant message with
# a usage block hasn't landed yet on the first few tool calls). Seeding with
# ok lets fast path serve the correct initial state for STATUS_MAX_AGE (90s),
# during which real post-compact usage entries accumulate in the JSONL.
cat > "$PROJECT_ROOT/.context/working/.budget-status" <<BUDGET_EOF
{"level": "ok", "tokens": 0, "timestamp": $(date +%s), "source": "post-compact-resume"}
BUDGET_EOF

# T-1088: Write the session-start timestamp in ISO-8601 Z format. budget-gate.sh
# and checkpoint.sh read this file and filter JSONL usage entries lexically
# so pre-compact entries (still in the same JSONL because claude -c continues
# the file) are excluded from the "last usage" scan. This is the authoritative
# fix for the T-1087 regression class; T-1087's ok-seed is the safety net that
# covers the first ~90 seconds before the slow-path runs.
date -u +"%Y-%m-%dT%H:%M:%S.000Z" > "$PROJECT_ROOT/.context/working/.session-start-ts"

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

# Onboarding enforcement (T-535) — surface incomplete onboarding tasks prominently
ONBOARDING_MARKER="$PROJECT_ROOT/.context/working/.onboarding-complete"
if [ ! -f "$ONBOARDING_MARKER" ]; then
    ONBOARDING_LIST=""
    for tf in "$PROJECT_ROOT"/.tasks/active/T-*.md; do
        [ -f "$tf" ] || continue
        if head -20 "$tf" | grep -q '^tags:.*onboarding' 2>/dev/null; then
            tf_status=$(grep "^status:" "$tf" | head -1 | sed 's/status:[[:space:]]*//')
            if [ "$tf_status" != "work-completed" ]; then
                tf_id=$(grep "^id:" "$tf" | head -1 | sed 's/id:[[:space:]]*//')
                tf_name=$(grep "^name:" "$tf" | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
                ONBOARDING_LIST="${ONBOARDING_LIST}
- ${tf_id}: ${tf_name} (${tf_status})"
            fi
        fi
    done
    if [ -n "$ONBOARDING_LIST" ]; then
        CONTEXT="${CONTEXT}
## ONBOARDING REQUIRED

Setup tasks must complete before other work. The PreToolUse gate will block non-onboarding edits.
${ONBOARDING_LIST}

Start with: \`fw work-on T-001\`
Skip (not recommended): \`fw onboarding skip\`

"
    fi
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
# T-1083: use FRAMEWORK_ROOT for script, PROJECT_ROOT for data — the consumer
# has .fabric/ but fabric.sh lives in .agentic-framework/.
if [ -f "$PROJECT_ROOT/.fabric/subsystems.yaml" ]; then
    FABRIC_OVERVIEW=$(PROJECT_ROOT="$PROJECT_ROOT" "$FRAMEWORK_ROOT/agents/fabric/fabric.sh" overview 2>/dev/null)
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
