---
id: T-1328
name: "Inception commit-limit hook overcounts via substring match (T-1130 vs T-11300, body-mentions)"
description: >
  Inception commit-limit hook overcounts via substring match (T-1130 vs T-11300, body-mentions)

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/git/lib/hooks.sh]
related_tasks: []
created: 2026-04-19T09:41:31Z
last_update: 2026-04-19T09:46:48Z
date_finished: 2026-04-19T09:46:48Z
---

# T-1328: Inception commit-limit hook overcounts via substring match (T-1130 vs T-11300, body-mentions)

## Context

`.git/hooks/commit-msg` (and the source template) gates inception commits using `git log --oneline --grep="$TASK_REF"`. The grep is unanchored — it matches `T-1130` inside `T-11300`, AND inside any commit body that mentions the ID in passing (e.g., a related commit body containing "T-1130 pickup"). Today: `git log --oneline --grep="T-1130" | wc -l` returns 2 commits even though zero commits actually target T-1130 — the hook then blocks the first legitimate commit on T-1130. Discovered while triaging T-1130 in this session.

## Acceptance Criteria

### Agent
- [x] Hook uses anchored match (`grep="$TASK_REF:"` with colon) to count only commits whose subject prefix targets the task
- [x] Source-of-truth template (in `agents/git/lib/` or wherever the hook is generated) updated, not just the local `.git/hooks/commit-msg`
- [x] After fix: `git log --oneline --grep="T-1130:" | wc -l` returns 0 for the current state of T-1130
- [x] Existing inception-gate behavior preserved for tasks WITH real commits (regression check via T-1326 — has 1 real commit, hook should still see 1)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [x] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification
test "$(git log --oneline | grep -cE '^[0-9a-f]+ T-1130:' || true)" = "0"
test "$(git log --oneline | grep -cE '^[0-9a-f]+ T-1326:' || true)" = "1"
grep -qE 'grep -cE "\^\[0-9a-f\]\+ \$\{TASK_REF\}:"' .git/hooks/commit-msg

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-19T09:41:31Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1328-inception-commit-limit-hook-overcounts-v.md
- **Context:** Initial task creation

### 2026-04-19T09:46:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
