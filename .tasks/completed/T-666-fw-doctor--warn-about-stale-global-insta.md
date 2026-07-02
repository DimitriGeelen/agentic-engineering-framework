---
id: T-666
name: "fw doctor — warn about stale global install at HOME/.agentic-framework"
description: >
  Phase 4 of T-662: Add a warning to fw doctor when HOME/.agentic-framework exists
  and ~/.local/bin/fw is still a symlink (not the shim). Guides users to run install.sh
  or fw upgrade to migrate.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: []
related_tasks: []
created: 2026-03-28T17:26:25Z
last_update: '2026-06-11T22:24:27Z'
date_finished: 2026-03-28T17:28:28Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 2
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=2 (body:env-class-handled); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-666: fw doctor — warn about stale global install at HOME/.agentic-framework

## Context

Phase 4 of T-662 (GO). Add a check to `fw doctor` that warns when `$HOME/.agentic-framework` exists and `~/.local/bin/fw` is still a symlink to it (not the shim). Guides users to migrate.

## Acceptance Criteria

### Agent
- [x] `fw doctor` checks for stale global install and shows WARN with migration instructions
- [x] Shows OK when shim is installed and global dir exists (can be removed)
- [x] Shows OK when no global install exists
- [x] Vendored `bin/fw` synced

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

### 2026-03-28T17:26:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-666-fw-doctor--warn-about-stale-global-insta.md
- **Context:** Initial task creation

### 2026-03-28T17:28:28Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-677f3ea3
- **Timestamp:** 2026-06-02T15:04:13Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
