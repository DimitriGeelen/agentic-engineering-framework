---
id: T-709
name: "Wire ntfy notifications into framework hooks — Tier 0, task complete, audit,
  handover"
description: >
  Wire fw_notify() calls into check-tier0.sh, update-task.sh, audit.sh, handover.sh.
  5 insertion points identified in T-707. Related: T-708, T-707 GO.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [ntfy, notifications]
components: [C-004, agents/context/check-tier0.sh, agents/handover/handover.sh, 
      agents/task-create/update-task.sh]
related_tasks: []
created: 2026-03-29T11:14:18Z
last_update: '2026-08-16T22:25:37Z'
date_finished: 2026-03-29T11:18:56Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-AUTONOMY=0 (no-signal);
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-709: Wire ntfy notifications into framework hooks — Tier 0, task complete, audit, handover

## Context

Wire `fw_notify()` from `lib/notify.sh` (T-708) into 5 framework hook/agent scripts. Design: `docs/reports/T-707-ntfy-deep-dive.md`

## Acceptance Criteria

### Agent
- [x] `check-tier0.sh` — notifies on Tier 0 block (task_blocked trigger)
- [x] `update-task.sh` — notifies on work-completed transition
- [x] `update-task.sh` — notifies on partial-complete (human AC ready)
- [x] `audit.sh` — notifies on FAIL_COUNT > 0
- [x] `handover.sh` — notifies on handover creation
- [x] All notifications are fire-and-forget (backgrounded)
- [x] All notifications respect NTFY_ENABLED flag

## Verification

grep -q "fw_notify" agents/context/check-tier0.sh
grep -q "fw_notify" agents/task-create/update-task.sh
grep -q "fw_notify" agents/audit/audit.sh
grep -q "fw_notify" agents/handover/handover.sh
bash -n agents/context/check-tier0.sh
bash -n agents/task-create/update-task.sh
bash -n agents/audit/audit.sh
bash -n agents/handover/handover.sh

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

### 2026-03-29T11:14:18Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-709-wire-ntfy-notifications-into-framework-h.md
- **Context:** Initial task creation

### 2026-03-29T11:16:19Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-29T11:18:56Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-bc90d8ca
- **Timestamp:** 2026-06-02T15:04:28Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
