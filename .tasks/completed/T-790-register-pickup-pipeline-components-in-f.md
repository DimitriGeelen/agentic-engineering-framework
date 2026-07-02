---
id: T-790
name: "Register pickup pipeline components in fabric"
description: >
  Register pickup pipeline components in fabric

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-30T14:19:59Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T14:21:30Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-790: Register pickup pipeline components in fabric

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] lib/pickup.sh registered in fabric
- [x] tests/unit/lib_pickup.bats registered in fabric
- [x] 6 additional test files from T-788 registered

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     Examples:
       python3 -c "import yaml; yaml.safe_load(open('path/to/file.yaml'))"
       curl -sf http://localhost:3000/page
       grep -q "expected_string" output_file.txt
-->

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

### 2026-03-30T14:19:59Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-790-register-pickup-pipeline-components-in-f.md
- **Context:** Initial task creation

### 2026-03-30T14:21:30Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c31626c8
- **Timestamp:** 2026-06-02T15:04:53Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Per-AC findings:**

- **AC#1 (Agent)** — lib/pickup.sh registered in fabric
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/pickup.sh in: lib/pickup.sh registered in fabric`
- **AC#2 (Agent)** — tests/unit/lib_pickup.bats registered in fabric
  - **AC-verify-mismatch** (narrow, heuristic) — `path=tests/unit/lib_pickup.bats in: tests/unit/lib_pickup.bats registered in fabric`
