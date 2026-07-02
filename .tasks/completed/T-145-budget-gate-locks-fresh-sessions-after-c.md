---
id: T-145
name: "Budget gate locks fresh sessions after compaction — JSONL accumulates"
description: >
  After /compact, the JSONL transcript retains all pre-compaction messages. budget-gate.sh
  reads the full file and sees 150K+ tokens, writing critical to .budget-status. Fresh
  sessions inherit this lock. The gate self-reinforces: each blocked call re-reads
  the JSONL and re-confirms critical. Fix: detect session boundaries (compaction markers)
  in JSONL, or base token count on actual active context, not historical transcript.

status: work-completed
workflow_type: build
owner: agent
horizon: null
related_tasks: []
created: 2026-02-18T09:38:27Z
last_update: '2026-06-11T22:23:48Z'
date_finished: 2026-02-18T09:40:17Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-145: Budget gate locks fresh sessions after compaction — JSONL accumulates

## Context

Budget gate deadlock after compaction: stale `.budget-status` (critical) blocks `fw context init` which is the command that would reset the status.

## Acceptance Criteria

- [x] budget-gate.sh allowlist includes fw context init, fw resume, git status/log/diff
- [x] pre-compact.sh resets .budget-status and .budget-gate-counter before compaction
- [x] Regex allowlist passes 13/13 test cases

## Verification

grep -q 'context.s.init' agents/context/budget-gate.sh
grep -q 'budget-gate-counter' agents/context/pre-compact.sh
grep -q 'budget-status' agents/context/pre-compact.sh

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

### 2026-02-18T09:38:27Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-145-budget-gate-locks-fresh-sessions-after-c.md
- **Context:** Initial task creation

### 2026-02-18T09:40:17Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T09:40:17Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-7c848434
- **Timestamp:** 2026-06-02T14:57:37Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
