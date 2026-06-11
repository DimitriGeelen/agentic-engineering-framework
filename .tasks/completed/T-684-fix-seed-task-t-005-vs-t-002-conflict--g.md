---
id: T-684
name: "Fix seed task T-005 vs T-002 conflict — .gitignore blocks handover commit"
description: >
  F-10: T-002 adds .context/ to .gitignore, but T-005 needs to commit a handover to
  .context/handovers/. These two seed tasks conflict. Either .context/handovers/ should
  be excluded from gitignore, or the onboarding template should not gitignore .context/.
  Discovered during T-679 vnx experiment.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T22:03:43Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T22:10:07Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-684: Fix seed task T-005 vs T-002 conflict — .gitignore blocks handover commit

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Added note to T-002 seed task: do not gitignore `.context/` or `.tasks/`
- [x] Suggests safe alternatives: README typo, code comment, build artifacts
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

### 2026-03-28T22:03:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-684-fix-seed-task-t-005-vs-t-002-conflict--g.md
- **Context:** Initial task creation

### 2026-03-28T22:09:02Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T22:10:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-425ebb27
- **Timestamp:** 2026-06-02T15:04:20Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
