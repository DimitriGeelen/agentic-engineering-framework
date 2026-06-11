---
id: T-162
name: "Web edge case tests — subprocess timeouts, error parsing, malformed YAML"
description: >
  Extend test_app.py with: subprocess.TimeoutExpired handling for all 18 fw CLI calls,
  stderr error parsing, malformed YAML input (corrupt assumptions.yaml, gaps.yaml),
  missing .context directories, empty task files. Ref: T-158, /tmp/T-158-web-audit.md

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-18T13:30:49Z
last_update: '2026-06-11T22:23:53Z'
date_finished: 2026-02-19T00:14:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:53Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-162: Web edge case tests — subprocess timeouts, error parsing, malformed YAML

## Context

<!-- One sentence for small tasks. Link to design docs for substantial ones. -->

## Acceptance Criteria

- [x] Subprocess TimeoutExpired tests for task API endpoints (status, create, horizon, owner, type)
- [x] Subprocess non-zero exit code (stderr error) tests for task API endpoints
- [x] Malformed YAML handling: corrupt task files, corrupt project YAML (gaps, learnings, decisions)
- [x] Missing .context directories: pages render gracefully without .context/audits, handovers, etc.
- [x] Empty/minimal task files: task list and detail handle files with no frontmatter
- [x] All new tests pass

## Verification

python3 -m pytest web/test_app.py -k "Subprocess or Malformed or Missing or Empty" -q 2>&1 | tail -3 | grep -q "24 passed"

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

### 2026-02-18T13:30:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-162-web-edge-case-tests--subprocess-timeouts.md
- **Context:** Initial task creation

### 2026-02-19T00:08:59Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-19T00:14:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-847d7b04
- **Timestamp:** 2026-06-02T14:58:45Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 1
     - evidence: `python3 -m pytest web/test_app.py -k "Subprocess or Malformed or Missing or Empty" -q 2>&1 | tail -3 | grep -q "24 passed"`
