---
id: T-036
name: Add practices.yaml and auto-healing trigger
description: >
  Create practices.yaml as structured queryable data and auto-trigger healing diagnosis
  when task status changes to issues or blocked
status: work-completed
workflow_type: build
owner: claude-code
priority: medium
tags: [practices, structured-data]
agents:
  primary: claude-code
  supporting: []
created: 2026-02-13T23:45:30Z
last_update: '2026-06-11T22:23:36Z'
date_finished: 2026-02-14T09:03:31Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:36Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-036: Add practices.yaml and auto-healing trigger

## Design Record

**practices.yaml:** Machine-queryable YAML with all 7 practices from 015-Practices.md. Each entry has id, name, derived_from, description, anti_pattern, origin_task, origin_date, status, applications.

**Auto-healing trigger:** Deferred — requires task status change detection mechanism that doesn't exist yet. Will be implemented when task status transitions are formalized (e.g., via fw task update command).

## Updates

### 2026-02-14T09:03:31Z — build-completed [claude-code]
- **Action:** Created .context/project/practices.yaml with all 7 practices
- **Scope note:** Auto-healing trigger deferred (no task status transition mechanism exists yet)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-a3f4e6af
- **Timestamp:** 2026-06-02T14:54:10Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
