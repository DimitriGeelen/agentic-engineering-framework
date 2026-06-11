---
id: T-683
name: "Fix seed task T-001 verification — fw audit too strict for fresh projects"
description: >
  F-8: Seed task T-001 verification requires fw audit exit 0, but fresh projects always
  have baseline warnings/failures. Change verification to fw doctor (which passes)
  or fw audit --warn-only. Discovered during T-679 vnx experiment.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T22:03:36Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T22:07:40Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 4
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=4 (body:fw-audit-or-doctor); D3=0
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-683: Fix seed task T-001 verification — fw audit too strict for fresh projects

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] Change T-001 verification in `lib/seeds/tasks/existing-project/T-001-orientation-and-framework-health.md` — `fw audit; test $? -le 1` allows warnings
- [x] Also fix greenfield T-001 — same fix applied
- [x] Verified: exit code 1 (warnings) passes, exit code 2 (failures) blocks
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

### 2026-03-28T22:03:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-683-fix-seed-task-t-001-verification--fw-aud.md
- **Context:** Initial task creation

### 2026-03-28T22:05:37Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-28T22:07:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-c840f7f7
- **Timestamp:** 2026-06-02T15:04:19Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
