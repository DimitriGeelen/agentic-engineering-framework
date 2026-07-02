---
id: T-616
name: "Add consumer staleness check to fw doctor"
description: >
  fw doctor is framework-centric, not consumer-aware. Add checks: version drift detection,
  hook completeness by TYPE, CLAUDE.md governance hash, upgrade timestamp. From T-614
  investigation.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [bin/fw]
related_tasks: []
created: 2026-03-25T20:17:21Z
last_update: '2026-06-11T22:24:25Z'
date_finished: 2026-03-25T22:20:03Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:25Z'
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

# T-616: Add consumer staleness check to fw doctor

## Context

`fw doctor` only checks framework health. T-614 showed all 7 consumers silently decayed. Add consumer fleet scan.

## Acceptance Criteria

### Agent
- [x] `fw doctor` scans /opt for `.framework.yaml` files to discover consumers
- [x] Reports each consumer: name, version, hook count vs framework
- [x] Version mismatch shown as WARN with `fw upgrade <path>` suggestion
- [x] Missing hooks shown as WARN with specific hook names
- [x] Works when no consumers exist (graceful skip)

## Verification

bash -n bin/fw
grep -q 'Consumer Projects' bin/fw

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

### 2026-03-25T20:17:21Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-616-add-consumer-staleness-check-to-fw-docto.md
- **Context:** Initial task creation

### 2026-03-25T22:17:33Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-25T22:20:03Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b35a9dec
- **Timestamp:** 2026-06-02T15:03:55Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
