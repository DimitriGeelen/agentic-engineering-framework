---
id: T-760
name: "Fix shellcheck warnings in core lib scripts (bus.sh, dispatch.sh, colors.sh)"
description: >
  Fix shellcheck warnings in core lib scripts (bus.sh, dispatch.sh, colors.sh)

status: work-completed
workflow_type: refactor
owner: agent
horizon:
tags: []
components: [lib/bus.sh, lib/colors.sh, lib/dispatch.sh]
related_tasks: []
created: 2026-03-30T07:30:54Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T07:33:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 2
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=2 
      (components:substrate-edit); F3=0 (no-signal); F1=0 (no-signal); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-760: Fix shellcheck warnings in core lib scripts (bus.sh, dispatch.sh, colors.sh)

## Context

Fix shellcheck warnings in core lib scripts: unused variable in bus.sh, missing ssh -n in dispatch.sh, exported colors in colors.sh.

## Acceptance Criteria

### Agent
- [x] bus.sh: Remove unused total_bytes variable (SC2034)
- [x] dispatch.sh: Add -n flag to ssh to prevent stdin swallowing (SC2095)
- [x] colors.sh: Add shellcheck disable directive for SC2034 (variables used by sourcing scripts)
- [x] All existing tests still pass (bus + dispatch: 8/8)

### Human
<!-- Criteria requiring human verification (UI/UX, subjective quality). Not blocking.
     Remove this section if all criteria are agent-verifiable.
     Each criterion MUST include Steps/Expected/If-not so the human can act without guessing.
     Optionally prefix with [RUBBER-STAMP] or [REVIEW] for prioritization.
     Example:
       - [ ] [REVIEW] Dashboard renders correctly
         **Steps:**
         1. Open https://example.com/dashboard in browser
         2. Verify all panels load within 2 seconds
         3. Check browser console for errors
         **Expected:** All panels visible, no console errors
         **If not:** Screenshot the broken panel and note the console error
-->

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

### 2026-03-30T07:30:54Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-760-fix-shellcheck-warnings-in-core-lib-scri.md
- **Context:** Initial task creation

### 2026-03-30T07:33:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b1f016bf
- **Timestamp:** 2026-06-02T15:04:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
