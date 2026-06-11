---
id: T-834
name: "Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for
  Opus 4.6"
description: >
  Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus
  4.6

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-04T10:07:22Z
last_update: '2026-06-11T22:24:30Z'
date_finished: 2026-04-04T10:10:37Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:30Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 4
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=4 (body:structural-gate); D2=0 (no-signal); D3=0 (no-signal); 
      D4=3 (body:portability-abstraction); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-834: Fix budget gate false critical — update CONTEXT_WINDOW default 200K to 1M for Opus 4.6

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

### Agent
- [x] budget-gate.sh default changed from 200000 to 1000000
- [x] checkpoint.sh default changed from 200000 to 1000000
- [x] lib/config.sh registry default updated
- [x] CLAUDE.md thresholds and documentation updated
- [x] fw_config_int returns 1000000 for CONTEXT_WINDOW

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

### 2026-04-04T10:07:22Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-834-fix-budget-gate-false-critical--update-c.md
- **Context:** Initial task creation

### 2026-04-04T10:10:37Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-321be2b0
- **Timestamp:** 2026-06-02T15:05:08Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Per-AC findings:**

- **AC#3 (Agent)** — lib/config.sh registry default updated
  - **AC-verify-mismatch** (narrow, heuristic) — `path=lib/config.sh in: lib/config.sh registry default updated`
