---
id: T-871
name: "Fix unbound PATTERNS_FILE variable in healing agent"
description: >
  Fix unbound PATTERNS_FILE variable in healing agent

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [agents/healing/healing.sh]
related_tasks: []
created: 2026-04-04T23:10:03Z
last_update: '2026-06-11T22:24:31Z'
date_finished: 2026-04-04T23:11:45Z
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

# T-871: Fix unbound PATTERNS_FILE variable in healing agent

## Context

`PATTERNS_FILE` referenced in healing agent's patterns.sh and resolve.sh but never defined. Under `set -u`, `fw healing patterns` crashes with "unbound variable".

## Acceptance Criteria

### Agent
- [x] PATTERNS_FILE defined in healing.sh
- [x] `fw healing patterns` runs without error
- [x] Integration test passes

## Verification

bin/fw healing patterns 2>&1; test $? -eq 0
grep -q 'PATTERNS_FILE' agents/healing/healing.sh

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

### 2026-04-04T23:10:03Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-871-fix-unbound-patternsfile-variable-in-hea.md
- **Context:** Initial task creation

### 2026-04-04T23:11:45Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aea2c8b6
- **Timestamp:** 2026-06-02T15:05:22Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
