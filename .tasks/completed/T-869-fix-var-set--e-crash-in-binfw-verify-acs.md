---
id: T-869
name: "Fix ((var++)) set -e crash in bin/fw verify-acs"
description: >
  Fix ((var++)) set -e crash in bin/fw verify-acs

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [bin/fw]
related_tasks: []
created: 2026-04-04T22:44:44Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-04T22:46:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
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

# T-869: Fix ((var++)) set -e crash in bin/fw verify-acs

## Context

`((var++))` under `set -euo pipefail` crashes when var=0 (returns exit 1). bin/fw verify-acs uses this pattern at lines 1588, 1593, 1596 for total/passed/failed counters.

## Acceptance Criteria

### Agent
- [x] No `((var++))` pattern in bin/fw
- [x] bin/fw verify-acs runs without crash

## Verification

bash -c 'grep -qP "\(\(\w+\+\+\)\)" bin/fw && exit 1 || exit 0'

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

### 2026-04-04T22:44:44Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-869-fix-var-set--e-crash-in-binfw-verify-acs.md
- **Context:** Initial task creation

### 2026-04-04T22:46:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3dd86950
- **Timestamp:** 2026-06-02T15:05:21Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
