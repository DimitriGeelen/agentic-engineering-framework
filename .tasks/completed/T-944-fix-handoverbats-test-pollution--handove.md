---
id: T-944
name: "Fix handover.bats test pollution — handover tests overwrite real LATEST.md"
description: >
  Fix handover.bats test pollution — handover tests overwrite real LATEST.md

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [tests/unit/handover.bats]
related_tasks: []
created: 2026-04-06T10:34:28Z
last_update: '2026-06-11T22:24:33Z'
date_finished: 2026-04-06T10:36:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:33Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-944: Fix handover.bats test pollution — handover tests overwrite real LATEST.md

## Context

handover.bats runs `--no-commit` which creates real handover files and updates LATEST.md symlink. Need to save/restore symlink target and clean up test-generated files.

## Acceptance Criteria

### Agent
- [x] handover.bats saves/restores LATEST.md symlink in setup/teardown
- [x] Test-generated handover files cleaned up
- [x] All tests still pass (10/10)
- [x] LATEST.md points to same target after test run (verified: S-2026-0406-1229.md)

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

### 2026-04-06T10:34:28Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-944-fix-handoverbats-test-pollution--handove.md
- **Context:** Initial task creation

### 2026-04-06T10:36:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-9a1e2fbf
- **Timestamp:** 2026-06-02T15:05:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
