---
id: T-393
name: "Fix handover TODO rot — template, audit, and cleanup"
description: >
  Fix handover TODO rot — template, audit, and cleanup

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: [handover, audit, quality]
components: []
related_tasks: []
created: 2026-03-09T17:33:55Z
last_update: '2026-06-11T22:24:20Z'
date_finished: 2026-03-09T17:36:36Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:20Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 3
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=3 (body:test-or-audit-check); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-393: Fix handover TODO rot — template, audit, and cleanup

## Context

273 handover files had accumulated 5,982 unfilled [TODO]s. Root cause: handover template generated [TODO] blocks for ALL active tasks (including work-completed ones awaiting human review). Auto-compaction generates handovers without filling them. D8 audit only checked LATEST.md.

## Acceptance Criteria

### Agent
- [x] Handover template skips [TODO] blocks for work-completed tasks (summarizes them instead)
- [x] D8b audit check scans last 10 handovers for TODO rot (not just LATEST)
- [x] 98 stale handover files cleaned — [TODO]s replaced with "Not recorded"
- [x] New handover generates ~31 TODOs (down from 91) — only for active tasks + global sections

## Verification

# Template fix: work-completed tasks don't generate [TODO] blocks
grep -q 'pending_completed' agents/handover/handover.sh
# Audit fix: D8b check exists
grep -q 'D8b' agents/audit/audit.sh
# Archive cleanup: no stale [TODO: What was just done] in handovers
test "$(grep -rl '\[TODO: What was just done' .context/handovers/S-*.md | wc -l)" -eq 0

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

### 2026-03-09T17:33:55Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-393-fix-handover-todo-rot--template-audit-an.md
- **Context:** Initial task creation

### 2026-03-09T17:36:36Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d07434a3
- **Timestamp:** 2026-06-02T15:02:34Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
