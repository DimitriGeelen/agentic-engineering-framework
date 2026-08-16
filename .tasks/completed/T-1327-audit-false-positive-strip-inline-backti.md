---
id: T-1327
name: "Audit false-positive: strip inline backticks before placeholder pattern match
  (T-1298 meta-block)"
description: >
  Audit false-positive: strip inline backticks before placeholder pattern match (T-1298
  meta-block)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [lib/task-audit.sh, tests/unit/lib_task_audit.bats]
related_tasks: []
created: 2026-04-19T09:12:56Z
last_update: '2026-08-16T22:24:29Z'
date_finished: 2026-04-19T09:30:29Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:45Z'
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
  - ts: '2026-08-16T22:24:29Z'
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

# T-1327: Audit false-positive: strip inline backticks before placeholder pattern match (T-1298 meta-block)

## Context

`audit_task_placeholders` (lib/task-audit.sh) flags inline-backtick mentions of pattern strings (`` `[TODO]` ``, `` `[Criterion N]` ``, etc.) as unfilled placeholders. T-1298's Recommendation legitimately quotes these patterns and is therefore impossible to decide via Watchtower (10+ HTTP 500 in `.context/working/watchtower.log`). Same trap exists for any future task documenting the placeholder detector. Fix: strip inline backtick spans before pattern match.

## Acceptance Criteria

### Agent
- [x] `lib/task-audit.sh:audit_task_placeholders` strips inline backtick spans (`` `…` ``) before pattern match
- [x] New bats test in `tests/unit/lib_task_audit.bats` covers: inline-backticked `[TODO]` is NOT flagged; bare `[TODO]` IS flagged; mixed line with both bare and backticked is flagged
- [x] Existing bats `tests/unit/lib_task_audit.bats` still passes
- [x] Running audit against current `.tasks/active/T-1298-pickup-inception-template-gono-go-placeh.md` exits 0

## Verification
bash -c 'source lib/task-audit.sh && audit_task_placeholders .tasks/active/T-1298-pickup-inception-template-gono-go-placeh.md'
bats tests/unit/lib_task_audit.bats

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

### 2026-04-19T09:12:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1327-audit-false-positive-strip-inline-backti.md
- **Context:** Initial task creation

### 2026-04-19T09:30:29Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-e8546ad3
- **Timestamp:** 2026-06-02T14:56:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
