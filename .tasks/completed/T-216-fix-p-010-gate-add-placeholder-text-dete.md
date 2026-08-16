---
id: T-216
name: "Fix P-010 gate: add placeholder text detection to reject skeleton ACs"
description: >
  Fix P-010 gate: add placeholder text detection to reject skeleton ACs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-20T08:37:19Z
last_update: '2026-08-16T22:24:55Z'
date_finished: 2026-02-20T08:40:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:09Z'
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
  - ts: '2026-08-16T22:24:55Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-216: Fix P-010 gate: add placeholder text detection to reject skeleton ACs

## Context

P-010 gate (update-task.sh) counts `[x]` vs `[ ]` but doesn't check AC content. Template placeholders like `[x] [First criterion]` pass the gate. Discovered in AC quality audit across 212 tasks.

## Acceptance Criteria

### Agent
- [x] update-task.sh rejects `[x] [First criterion]` style skeleton ACs at completion
- [x] update-task.sh still passes real ACs that are checked
- [x] Both Agent/Human split mode and legacy (no split) mode are covered
- [x] --force bypass still works for skeleton ACs (with warning)
- [x] Existing unit tests (84) still pass

## Verification

grep -q "skeleton placeholders" agents/task-create/update-task.sh
# Test that the placeholder pattern detection exists
grep -q "First.*Second.*Third.*Fourth.*Fifth" agents/task-create/update-task.sh
# Shellcheck has no new errors (pre-existing SC2144/SC2012/SC2001 OK)
! shellcheck agents/task-create/update-task.sh 2>&1 | grep -v "SC2144\|SC2012\|SC2001" | grep -q "error"

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

### 2026-02-20T08:37:19Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-216-fix-p-010-gate-add-placeholder-text-dete.md
- **Context:** Initial task creation

### 2026-02-20T08:40:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-23085f0f
- **Timestamp:** 2026-06-02T15:01:28Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 5
     - evidence: `! shellcheck agents/task-create/update-task.sh 2>&1 | grep -v "SC2144\|SC2012\|SC2001" | grep -q "error"`
