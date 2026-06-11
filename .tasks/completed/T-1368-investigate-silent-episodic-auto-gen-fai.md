---
id: T-1368
name: "investigate silent episodic auto-gen failure across 4 tasks"
description: >
  investigate silent episodic auto-gen failure across 4 tasks

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [tests/unit/update_task_episodic_gen.bats]
related_tasks: []
created: 2026-04-20T20:35:02Z
last_update: '2026-06-11T22:23:46Z'
date_finished: 2026-04-20T20:37:50Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:46Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 3
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=3 
      (body:component-silent-failure); D3=0 (no-signal); D4=0 (no-signal); 
      F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1368: investigate silent episodic auto-gen failure across 4 tasks

## Context

T-1363, T-1364, T-1366, T-1367 all completed via `fw task update --status work-completed` (Updates sections show `[task-update-agent]` entries and `date_finished` is populated), but none produced an auto-generated episodic during completion. Human generated T-1363/T-1364 episodics manually in commit 968c5034; T-1366/T-1367 were generated manually now. Sandbox reproduction of the exact real task file (T-1366) with the same inputs successfully generates the episodic, so the bug is **environmental**, not in the code path.

Given 4/4 failure rate within one session, the silent-failure WARN at update-task.sh:851 is either being printed-but-unread, or not printed at all. This is a regression in T-1169's silent-failure detector — either the detector is broken, or the auto-gen is completing + deleting the file.

## Acceptance Criteria

### Agent
- [x] T-1366 and T-1367 episodic files generated and committed (addresses handover gap warning)
- [x] Learning recorded in learnings.yaml referencing the 4-task streak and the sandbox-reproduction discrepancy (L-027)
- [x] Concern registered in concerns.yaml (silent-failure-of-silent-failure-detector) with status watching until reproduction conditions are identified (G-054)
- [x] Regression test added: tests/unit/ bats test that completes a synthetic task via update-task.sh and asserts the episodic file exists afterward (tests/unit/update_task_episodic_gen.bats, 2 tests passing)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

## Verification

# Shell commands that MUST pass before work-completed. One per line.
test -f .context/episodic/T-1366.yaml
test -f .context/episodic/T-1367.yaml
grep -q "L-027" .context/project/learnings.yaml
grep -qi "episodic auto-gen silent failure" .context/project/concerns.yaml
bats tests/unit/update_task_episodic_gen.bats

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

### 2026-04-20T20:35:02Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1368-investigate-silent-episodic-auto-gen-fai.md
- **Context:** Initial task creation

### 2026-04-20T20:37:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4b3ef478
- **Timestamp:** 2026-06-02T14:56:59Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
