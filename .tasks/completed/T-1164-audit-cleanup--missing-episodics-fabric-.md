---
id: T-1164
name: "Audit cleanup — missing episodics, fabric drift, stale task anomalies"
description: >
  Audit cleanup — missing episodics, fabric drift, stale task anomalies

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-04-12T13:08:19Z
last_update: '2026-06-11T22:23:41Z'
date_finished: 2026-04-12T13:13:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 1
    rationale: D1=0 (no-signal); D2=4 (body:fw-audit-or-doctor); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=1 
      (body/components:component-fabric-incidental)
    rubric_sha: e4a00f38e801
---

# T-1164: Audit cleanup — missing episodics, fabric drift, stale task anomalies

## Context

Audit run 2026-04-12 shows 9 WARN + 1 FAIL. Fixable items: 4 missing episodics, 2 orphaned episodics, 1 unchecked AC. The FAIL is 38+ tasks in human review queue >30d — not agent-fixable.

## Acceptance Criteria

### Agent
- [x] Generate episodic summaries for T-1154, T-1155, T-1158, T-1163
- [x] Clean orphaned episodics (T-785, T-779) — already gone, historical audit cache artifact
- [x] Verify T-1093 unchecked AC status — placeholder ACs in completed task, historical artifact (not worth modifying completed files)
- [x] Audit warn count reduced from baseline (4 missing episodic warnings eliminated)

## Verification

test -f .context/episodic/T-1154.yaml
test -f .context/episodic/T-1155.yaml
test -f .context/episodic/T-1158.yaml
test -f .context/episodic/T-1163.yaml

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

### 2026-04-12T13:08:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1164-audit-cleanup--missing-episodics-fabric-.md
- **Context:** Initial task creation

### 2026-04-12T13:13:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-4e7402ec
- **Timestamp:** 2026-06-02T14:55:36Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
