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
            tf_status=$({ grep "^status:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
            if [ "$tf_status" != "work-completed" ]; then
                tf_id=$({ grep "^id:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/id:[[:space:]]*//')
                tf_name=$({ grep "^name:" "$tf" 2>/dev/null || true; } | head -1 | sed 's/name:[[:space:]]*//' | tr -d '"')
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

# T-1661: Current arc focus (single arc, mirrors task focus model).
ARC_FOCUS_FILE="$PROJECT_ROOT/.context/working/arc-focus.yaml"
if [ -f "$ARC_FOCUS_FILE" ]; then
    CURRENT_ARC=$(grep "^current_arc:" "$ARC_FOCUS_FILE" 2>/dev/null | cut -d: -f2 | tr -d ' "')
    if [ -n "$CURRENT_ARC" ] && [ "$CURRENT_ARC" != "null" ]; then
        CONTEXT="${CONTEXT}
## Current Arc: ${CURRENT_ARC}
"
    fi
fi

# Active tasks summary
# T-2160 (arc-009 Slice 1): split work-completed (partial-complete = Agent ACs
# done, Human ACs pending) into a separate listing. Primary "Active Tasks" list
# carries only in-progress entries (started-work / captured / issues). Mirrors
# the handover footer split.
TASK_SUMMARY=""
PARTIAL_SUMMARY=""
PARTIAL_COUNT=0
for f in "$PROJECT_ROOT/.tasks/active"/*.md; do
    [ -f "$f" ] || continue
    tid=$({ grep "^id:" "$f" 2>/dev/null || true; } | head -1 | sed 's/id:[[:space:]]*//')
    tname=$({ grep "^name:" "$f" 2>/dev/null || true; } | head -1 | sed 's/name:[[:space:]]*//')
    tstatus=$({ grep "^status:" "$f" 2>/dev/null || true; } | head -1 | sed 's/status:[[:space:]]*//')
    thoriz=$({ grep "^horizon:" "$f" 2>/dev/null || true; } | head -1 | sed 's/horizon:[[:space:]]*//' || echo "now")
    if [ "$tstatus" = "work-completed" ]; then
        PARTIAL_SUMMARY="${PARTIAL_SUMMARY}
- ${tid}: ${tname} (horizon: ${thoriz})"
        PARTIAL_COUNT=$((PARTIAL_COUNT + 1))
    else
        TASK_SUMMARY="${TASK_SUMMARY}
- ${tid}: ${tname} (${tstatus}, horizon: ${thoriz})"
    fi
done

if [ -n "$TASK_SUMMARY" ]; then
    CONTEXT="${CONTEXT}
## Active Tasks
${TASK_SUMMARY}
"
fi

if [ "$PARTIAL_COUNT" -gt 0 ]; then
    CONTEXT="${CONTEXT}
## Partial-Complete — awaiting human (${PARTIAL_COUNT} tasks)
Agent ACs done. Human ACs pending — see Watchtower /review/T-XXX or run \`bin/fw task review T-XXX\`.
${PARTIAL_SUMMARY}
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

# T-1630 (B-4 of T-1626): Hook health probe on session resume.
# Re-uses the lib/doctor-hook-exercise.py helper (B-3a / T-1629) to invoke
# every PreToolUse/PostToolUse hook from /tmp and surface any whose path
# doesn't resolve. Catches the T-1626 witness scenario (bare-relative
# .agentic-framework/bin/fw paths that break under cd) at the moment the
# agent's session resumes — not contingent on a real tool call firing.
# Silent on healthy hooks. Probe failure is non-fatal (degrades to no-op).
HOOK_EXERCISE_HELPER="${FW_DOCTOR_HOOK_EXERCISE:-$FRAMEWORK_ROOT/lib/doctor-hook-exercise.py}"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"
if [ -f "$HOOK_EXERCISE_HELPER" ] && [ -f "$SETTINGS_FILE" ]; then
    HOOK_PROBE=$(SETTINGS_FILE="$SETTINGS_FILE" python3 "$HOOK_EXERCISE_HELPER" 2>/dev/null || echo "")
    if [ -n "$HOOK_PROBE" ]; then
        HOOK_PROBE_FAIL=$(echo "$HOOK_PROBE" | head -1 | cut -d'|' -f2)
        if [ "${HOOK_PROBE_FAIL:-0}" -gt 0 ]; then
            HOOK_PROBE_DETAIL=$(echo "$HOOK_PROBE" | tail -n +2 | sed 's/^FAIL|/- /' | sed 's/|/ \/ /g')
            CONTEXT="${CONTEXT}

## Broken Hook Warning (T-1630)

The framework probed your hook configuration from /tmp (foreign CWD that mimics agent cd-drift) and found ${HOOK_PROBE_FAIL} hook(s) failed to resolve. This is the T-1626 witness pattern — these hooks will silently fail on every tool call until fixed.

${HOOK_PROBE_DETAIL}

**Action:** Run \`fw upgrade\` (regenerates hook paths to absolute form) or \`fw doctor\` for the full check.
"
        fi
    fi
fi

CONTEXT="${CONTEXT}

## Post-Compact Budget Note (T-1728)

Any budget assertion you see in the **handover narrative above** (e.g. \"Budget at 92%\", \"stopping new work\", \"context near critical\") was true at handover time but is **STALE in this resumed session**. The budget gauge was reset to {ok, 0, now} on resume (T-1087/T-1088). Do not defer to the prior session's budget statements when deciding whether to start new work.

- **Live gauge (fast):** \`cat .context/working/.budget-status\` — current level, tokens, age (refreshed by PostToolUse).
- **On-demand probe:** \`./agents/context/checkpoint.sh status\` — exact token count from session JSONL.
- **Doctor surface:** \`bin/fw doctor\` — flags out-of-range budget alongside other health.

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
