---
id: T-821
name: "Hook crash distinguishability — trap handlers + stderr headers for crash vs
  block"
description: >
  Hook crash distinguishability — trap handlers + stderr headers for crash vs block

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: [C-007, agents/context/check-active-task.sh, 
      agents/context/check-agent-dispatch.sh, C-008, 
      agents/context/check-project-boundary.sh, agents/context/check-tier0.sh, 
      bin/fw, lib/config.sh]
related_tasks: []
created: 2026-04-03T21:50:47Z
last_update: '2026-08-16T22:25:40Z'
date_finished: 2026-04-03T21:54:00Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:40Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] All PreToolUse hooks have ERR trap that emits "HOOK CRASHED" marker to stderr
- [x] Intentional blocks (exit 2) emit "BLOCKED BY POLICY" header in stderr (already present in existing code)
- [x] Crashes log to `.context/working/.hook-crashes.log`
- [x] `fw doctor` checks `.hook-crashes.log` for recent crashes

### Human
<!-- No human ACs — stderr changes only, no UI impact.
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

### 2026-04-03T21:50:47Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-821-hook-crash-distinguishability--trap-hand.md
- **Context:** Initial task creation

### 2026-04-03T21:54:00Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-fb9794df
- **Timestamp:** 2026-06-02T15:05:04Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
