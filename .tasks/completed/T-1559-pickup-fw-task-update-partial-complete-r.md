---
id: T-1559
name: "Pickup: fw task update partial-complete recheck does not honor --skip-acceptance-criteria
  (from 003-NTB-ATC-Plugin)"
description: >
  Auto-created from pickup envelope. Source: 003-NTB-ATC-Plugin, task T-225. Type:
  bug-report.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/task-create/update-task.sh]
related_tasks: []
created: 2026-04-27T18:38:01Z
last_update: '2026-06-11T22:23:51Z'
date_finished: 2026-04-27T20:16:34Z
source_task_id_in_origin: T-225
source_project_in_origin: "003-NTB-ATC-Plugin"
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:51Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1559: Pickup: fw task update partial-complete recheck does not honor --skip-acceptance-criteria (from 003-NTB-ATC-Plugin)

## Context

`fw task update --status work-completed --skip-acceptance-criteria` honors the
flag on the initial captured/started-work → work-completed transition
(`agents/task-create/update-task.sh:105-108`), but the partial-complete
recheck branch at lines 519-564 (entered when OLD_STATUS == NEW_STATUS ==
work-completed AND task still in active/) refuses archival whenever any AC
remains unchecked, ignoring SKIP_AC entirely.

Net effect: the auth-flag pattern is broken once a task slips into
partial-complete. Pickup P-016 (003-NTB-ATC-Plugin T-225, C-018) closed 20
tasks today via the workaround of editing AC checkboxes by hand.

## Acceptance Criteria

### Agent
- [x] `update-task.sh` partial-complete recheck branch honors `SKIP_AC`: when true, warn + `log_gate_bypass` + proceed with archival (move + episodic), mirroring the initial-transition branch logic.
- [x] Regression test `tests/unit/skip_ac_partial_complete.bats` covers: (a) partial-complete with no flag → blocked, stays in active/; (b) partial-complete + `--skip-acceptance-criteria` → archived to completed/; (c) bypass logged.

### Human
<!-- All ACs are agent-verifiable. -->

## Verification

bats tests/unit/skip_ac_partial_complete.bats

## RCA

**Symptom:** Running `fw task update T-XXX --status work-completed
--skip-acceptance-criteria` on a partial-complete task (status already
work-completed, file still in `.tasks/active/`, ≥1 unchecked Human AC) returns
exit 0 but does NOT archive the file. Output: "Still N/M ACs unchecked — task
stays in active/." Pickup P-016 evidence: 20 tasks closed today via the
checkbox-editing workaround.

**Root cause:** `agents/task-create/update-task.sh:530` partial-complete
recheck branch (entered when OLD_STATUS == NEW_STATUS == work-completed) gates
archival on `[ "$ALL_UNCHECKED" -eq 0 ]` only, completely ignoring the
`SKIP_AC` flag that the initial-transition branch (lines 105-108) honors.
Asymmetry: the same auth flag has different semantics on the two branches.

**Why structurally allowed:** The two branches were authored at different
times — the initial-transition gate was written first as a function
(`check_acceptance_criteria`, T-415), and the partial-complete recheck branch
was added later (T-193) as inline logic that re-implemented the AC count but
not the bypass handling. No regression test pinned the SKIP_AC contract on the
recheck branch, so the asymmetry was invisible until P-016's batched-closure
workflow exercised it.

**Prevention:**
- `tests/unit/skip_ac_partial_complete.bats` (4 cases) pins the SKIP_AC
  contract on the partial-complete recheck branch — including the bypass log
  entry being written with caller `partial_complete_recheck`.
- L-306 (capture below): "When implementing the same gate on two code paths,
  re-use the same gate function — don't reinvent it inline. Asymmetric
  bypass handling is invisible until the auth flag flows through both paths."

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

### 2026-04-27T18:38:01Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1559-pickup-fw-task-update-partial-complete-r.md
- **Context:** Initial task creation

### 2026-04-27T20:11:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now

## Reviewer Verdict (v1.5)

- **Scan ID:** R-540e9a84
- **Timestamp:** 2026-06-02T14:58:18Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-27T20:16:34Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
