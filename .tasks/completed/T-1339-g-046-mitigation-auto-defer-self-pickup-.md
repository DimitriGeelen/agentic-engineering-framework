---
id: T-1339
name: "G-046 mitigation: auto-defer self-pickup envelopes whose source_task is already
  completed"
description: >
  G-046 mitigation: auto-defer self-pickup envelopes whose source_task is already
  completed

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-19T16:48:55Z
last_update: '2026-06-11T22:23:45Z'
date_finished: 2026-04-19T16:53:05Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 3
      D4: 4
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:concern-ref); D2=0 (no-signal); D3=3 
      (body:component-discoverability); D4=4 (body:cross-machine); F-RECALL=1 
      (body:episodic-only); F-ORCH=0 (no-signal); F3=0 (no-signal); F1=0 
      (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1339: G-046 mitigation: auto-defer self-pickup envelopes whose source_task is already completed

## Context

G-046 mitigation. Pickup pipeline auto-creates inception tasks for every envelope, including envelopes a project sends to itself referencing tasks that are already completed. This generates structural noise — the handover shows 5 DEFER decisions this week on exactly this pattern (T-1124/1127/1130/1131/1132). Fix: skip envelopes where `source_project == local_project` AND the referenced `source_task_id` lives in `.tasks/completed/`. Move to `.context/pickup/auto-deferred/` for audit trail.

## Acceptance Criteria

### Agent
- [x] New helper `pickup_is_self_completed` added to `lib/pickup.sh` — returns 0 when envelope's source_project matches local basename AND source_task is in `.tasks/completed/`
- [x] `pickup_process_one` calls the helper after dedup check; on match, moves envelope to `$PICKUP_DIR/auto-deferred/` and returns without creating a task
- [x] Unit test (bats) covers four cases: self+completed=deferred, self+active=normal, cross-project=normal, missing-task-id=normal — all 4 pass
- [x] `bash -n lib/pickup.sh` passes
- [x] `bin/fw pickup status` still works (smoke)

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

bash -n lib/pickup.sh
bats tests/unit/pickup_self_deferred.bats
bin/fw pickup status

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

### 2026-04-19T16:48:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1339-g-046-mitigation-auto-defer-self-pickup-.md
- **Context:** Initial task creation

### 2026-04-19T16:53:05Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b0efb844
- **Timestamp:** 2026-06-02T14:56:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** yes
- **Findings:** none

- **Layer-1 escalations:** 1
  1. **cross-project-blast** (medium) — Cross-project or cross-repo change
     - matched: `cross-project`
