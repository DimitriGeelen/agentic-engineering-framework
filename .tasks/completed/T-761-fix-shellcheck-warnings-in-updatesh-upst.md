---
id: T-761
name: "Fix shellcheck warnings in update.sh, upstream.sh, init.sh, notify.sh, setup.sh"
description: >
  Fix shellcheck warnings in update.sh, upstream.sh, init.sh, notify.sh, setup.sh

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [lib/init.sh, lib/notify.sh, lib/setup.sh, lib/update.sh, 
      lib/upstream.sh]
related_tasks: []
created: 2026-03-30T07:33:52Z
last_update: '2026-06-11T22:24:29Z'
date_finished: 2026-03-30T07:37:50Z
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

# T-761: Fix shellcheck warnings in update.sh, upstream.sh, init.sh, notify.sh, setup.sh

## Context

Fix shellcheck warnings in 5 core lib scripts: trap quoting, unused variables, stdin swallowing.

## Acceptance Criteria

### Agent
- [x] update.sh: Fix SC2064 trap quoting + SC2115 rm -rf safety
- [x] upstream.sh: Remove unused BLUE variable (SC2034)
- [x] init.sh: Suppress SC2034 for first_run + fix SC2155 separate declare/assign
- [x] notify.sh: Suppress SC2034 for category (reserved parameter)
- [x] setup.sh: Suppress SC2034 for force (used by sourced init.sh)
- [x] All 5 files pass shellcheck with 0 warnings

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

### 2026-03-30T07:33:52Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-761-fix-shellcheck-warnings-in-updatesh-upst.md
- **Context:** Initial task creation

### 2026-03-30T07:37:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-cfb361b4
- **Timestamp:** 2026-06-02T15:04:47Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
