---
id: T-1698
name: "T-1697 hook fires only on partial-complete re-run, not fresh completion path"
description: >
  T-1697 hook fires only on partial-complete re-run, not fresh completion path

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: [agents/task-create/update-task.sh, bin/fw, lib/resolver.py, tests/unit/test_resolver.py]
related_tasks: []
created: 2026-05-03T13:08:30Z
last_update: 2026-05-03T13:10:17Z
date_finished: 2026-05-03T13:10:17Z
---

# T-1698: T-1697 hook fires only on partial-complete re-run, not fresh completion path

## Context

T-1697 wired the outcome back-prop hook into update-task.sh, but only into the
**partial-complete re-run** branch (line ~605). Fresh first-time completions
(OLD_STATUS != work-completed) flow through Trigger 2 (line ~911) which has
its own episodic-gen block at line ~1121 — and that path didn't get the hook.

Discovered when T-1697 itself was completed: the hook didn't fire (no
outcome row appeared in `dispatch-outcomes.jsonl` for T-1697), but ran
correctly when invoked manually via `bin/fw outcome backprop T-1697`.

Fix: replicate the hook block after the Trigger 2 episodic-gen block,
gated on `PARTIAL_COMPLETE != true`. Same best-effort semantics
(`>/dev/null 2>&1 || true`) — failure never blocks completion.

## Acceptance Criteria

### Agent
- [x] update-task.sh has the outcome-backprop hook in BOTH branches (partial-complete re-run AND Trigger 2 fresh completion) — `grep -c "outcome backprop" agents/task-create/update-task.sh` returns 2
- [x] After running `fw task update <task_id> --status work-completed` on a fresh task with at least one matching dispatch row, `dispatch-outcomes.jsonl` gains a row for that task_id
- [x] No regression: previously-passing test_outcome.py still passes
- [x] No regression: bin/fw doctor exit 0

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

test "$(grep -c 'outcome backprop' agents/task-create/update-task.sh)" -ge 2
python3 -m pytest tests/unit/test_outcome.py -q
bin/fw doctor

## RCA

**Symptom:** T-1697's outcome back-prop hook silently didn't fire when T-1697 itself was completed via `fw task update --status work-completed` — no row in `dispatch-outcomes.jsonl` despite a matching dispatch existing.

**Root cause:** update-task.sh has TWO branches that handle the work-completed lifecycle: (a) the partial-complete re-run path at line ~553 (when OLD_STATUS == NEW_STATUS == work-completed and the file is still in active/), and (b) the canonical first-time finalize path "Trigger 2" at line ~911 (when OLD_STATUS != work-completed). T-1697 added the hook only to (a). Fresh completions go through (b) and never invoked the hook.

**Why structurally allowed:** Two duplicate episodic-gen blocks exist by design (T-1160/T-1103/T-193 — partial-complete needs separate handling), but there is no test or lint that ensures hooks added "alongside episodic gen" land in BOTH locations. The contributor (me) saw one such block, added beside it, didn't notice the second. The unit tests only verified the hook function works in isolation; the integration path (`fw task update --status work-completed` actually fires backprop) was not tested.

**Prevention:** This RCA. Plus: T-1697's verification AC `grep -q "outcome backprop"` only required ONE occurrence — relaxing the count to `-c 2` (both branches) is added here. A stronger structural fix would unify the two blocks into a single `_finalize_task_completed` function so any new hook lands in one place — captured as a follow-on observation but not in scope for this fix.

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

### 2026-05-03T13:08:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1698-t-1697-hook-fires-only-on-partial-comple.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.4)

- **Scan ID:** R-1f799184
- **Timestamp:** 2026-05-03T13:10:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none

### 2026-05-03T13:10:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
