---
id: T-741
name: "Fix shellcheck safety warnings in bin/fw and key agent scripts"
description: >
  SC2115 rm-rf safety guard, SC2155 declare/assign split, SC2086 quoting in bin/fw
  and agent scripts.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-29T23:20:50Z
last_update: '2026-08-16T22:25:38Z'
date_finished: 2026-03-29T23:25:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:28Z'
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
  - ts: '2026-08-16T22:25:38Z'
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

# T-741: Fix shellcheck safety warnings in bin/fw and key agent scripts

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] SC2115: `rm -rf` uses `${var:?}` guard in bin/fw
- [x] SC2155: Declare and assign separately in bin/fw key functions (4 instances)
- [x] SC2086: Quote variable expansions in bin/fw rsync call (array approach)
- [x] Zero SC2115/SC2155/SC2086 warnings remain in bin/fw
- [x] Integration tests still pass

## Verification

# No SC2115 safety warnings in bin/fw
python3 -c "import subprocess; r=subprocess.run(['shellcheck','bin/fw'],capture_output=True,text=True); assert 'SC2115' not in r.stdout, 'SC2115 still present'; print('OK: no SC2115')"
# Integration tests pass
bats tests/integration/fw_version.bats

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

### 2026-03-29T23:20:50Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-741-fix-shellcheck-safety-warnings-in-binfw-.md
- **Context:** Initial task creation

### 2026-03-29T23:25:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-25a1c792
- **Timestamp:** 2026-06-02T15:04:40Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
