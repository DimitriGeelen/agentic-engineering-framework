---
id: T-417
name: "Create web/subprocess_utils.py — consistent git/fw command execution (P7)"
description: >
  Create web/subprocess_utils.py with run_git_command() and run_fw_command() helpers.
  Currently 3 separate subprocess implementations with inconsistent timeouts (none
  vs 10s), error checking, and encoding. Directive score: P7=7. Ref: docs/reports/T-411-refactoring-directive-scoring.md

status: work-completed
workflow_type: refactor
owner: agent
horizon: null
components: [web/blueprints/core.py, web/blueprints/metrics.py, 
      web/blueprints/quality.py, web/blueprints/session.py, 
      web/blueprints/tasks.py, web/subprocess_utils.py]
related_tasks: [T-411]
created: 2026-03-10T21:03:17Z
last_update: '2026-06-11T22:24:21Z'
date_finished: 2026-03-10T23:28:47Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:21Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 2
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=2 (body:lightly-promoted); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-417: Create web/subprocess_utils.py — consistent git/fw command execution (P7)

## Context

Refactoring finding P7 (score 7) from `docs/reports/T-411-refactoring-directive-scoring.md`.

**P7 — Subprocess error handling inconsistency:**
Three separate subprocess implementations: core.py (no timeout), quality.py (timeout=10, detailed),
session.py (timeout=10, different error style). See research artifact § "PYTHON BACKEND" row P7.

## Acceptance Criteria

### Agent
- [x] web/subprocess_utils.py created with run_git_command(args, timeout=10) and run_fw_command(args, timeout=30)
- [x] All blueprint subprocess.run calls replaced with utility functions
- [x] Consistent timeout, encoding (utf-8, errors=replace), and error handling
- [x] At least 3 call sites converted

### Human
<!-- No human verification needed for this refactoring -->

## Verification

test -f web/subprocess_utils.py
python3 -c "from web.subprocess_utils import run_git_command; print(run_git_command(['log', '--oneline', '-1']))"

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

### 2026-03-10T21:03:17Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-417-create-websubprocessutilspy--consistent-.md
- **Context:** Initial task creation

### 2026-03-10T23:17:27Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-10T23:28:47Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3df38db2
- **Timestamp:** 2026-06-02T15:02:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
