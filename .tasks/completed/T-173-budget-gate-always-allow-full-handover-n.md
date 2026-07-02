---
id: T-173
name: "Budget gate: always allow full handover, not just emergency skeleton"
description: >
  Current budget gate at critical (150K+) blocks Write/Edit/Bash so aggressively that
  even the handover routine can't fill in [TODO] sections. The human user couldn't
  bypass it either. Fix: (1) The gate should always allow full handover completion
  — if there's context space left, a proper handover is more valuable than an emergency
  skeleton. (2) Consider raising the critical threshold or making handover operations
  exempt from the gate. (3) The gate should distinguish between 'new work' (block)
  and 'wrap-up work' (allow). Evidence: S-2026-0218-1917 handover had unfilled TODOs
  because gate blocked edits at 154K.

status: work-completed
workflow_type: build
owner: claude-code
horizon: null
related_tasks: []
created: 2026-02-18T18:24:33Z
last_update: '2026-06-11T22:23:57Z'
date_finished: 2026-02-18T21:23:44Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:57Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-173: Budget gate: always allow full handover, not just emergency skeleton

## Context

At critical budget level, the gate blocked ALL Write/Edit — including handover file edits. Fix: allow Write/Edit to wrap-up paths (.context/, .tasks/, .claude/) at critical. Also allow git add and fw task in Bash allow-list.

## Acceptance Criteria

- [x] Write/Edit to .context/ paths allowed at critical level
- [x] Write/Edit to .tasks/ paths allowed at critical level
- [x] Write/Edit to .claude/ paths allowed at critical level
- [x] Write/Edit to source files still blocked at critical level
- [x] Bash allow-list includes git add, fw task, handover.sh, update-task.sh
- [x] Critical message updated to reflect new allowed operations

## Verification

# Verify wrap-up write detection exists in budget-gate.sh
grep -q "is_wrapup_write" agents/context/budget-gate.sh
# Verify .context/ is in allowed paths
grep -q "\.context/" agents/context/budget-gate.sh
# Verify .tasks/ is in allowed paths
grep -q "\.tasks/" agents/context/budget-gate.sh
# Verify git add is in allowed commands
grep -q "git.*add" agents/context/budget-gate.sh
# Verify handover.sh is in allowed commands
grep -q 'handover\\\.sh' agents/context/budget-gate.sh

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

### 2026-02-18T18:24:33Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-173-budget-gate-always-allow-full-handover-n.md
- **Context:** Initial task creation

### 2026-02-18T21:21:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-18T21:23:44Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c8b169ac
- **Timestamp:** 2026-06-02T14:59:26Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
