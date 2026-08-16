---
id: T-854
name: "Pass project name to Watchtower templates — resolve from project root, display
  in header"
description: >
  Pass project name to Watchtower templates — resolve from project root, display in
  header

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-04T18:16:16Z
last_update: '2026-08-16T22:25:41Z'
date_finished: 2026-04-04T21:58:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:31Z'
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
  - ts: '2026-08-16T22:25:41Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-854: Pass project name to Watchtower templates — resolve from project root, display in header

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] project_name available as Jinja global in templates (derived from PROJECT_ROOT basename)
- [x] Browser tab title includes project name (e.g., "Tasks — MyProject")
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

### 2026-04-04T18:16:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-854-pass-project-name-to-watchtower-template.md
- **Context:** Initial task creation

### 2026-04-04T21:58:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-2a086f4c
- **Timestamp:** 2026-06-02T15:05:15Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
