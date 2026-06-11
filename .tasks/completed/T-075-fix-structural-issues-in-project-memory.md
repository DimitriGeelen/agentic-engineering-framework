---
id: T-075
name: Fix structural issues in project memory
description: >
  Fix data quality issues found in T-072 audit: (1) L-013 duplicated in learnings.yaml
  — remove duplicate, fill TBD application field. (2) D-008 out of order in decisions.yaml
  — reorder. (3) D-011 missing alternatives_rejected and directives_served. (4) G-005
  evidence stale — update to 13 learnings, 9 practices. (5) Update P-002 applications
  counter from 0 to 7+ (T-013,T-024,T-061,T-063,T-064,T-065,T-067). (6) Update P-009
  applications counter. See docs/reports/2026-02-15-context-memory-audit.md Section
  3.
status: work-completed
workflow_type: build
owner: agent
created: 2026-02-15T16:57:20Z
last_update: '2026-06-11T22:23:37Z'
date_finished: 2026-02-16T19:31:48Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); F3=0 
      (no-signal); F1=1 (body/components:context-fabric-incidental); F2=0 
      (no-signal)
    rubric_sha: e4a00f38e801
---

# T-075: Fix structural issues in project memory

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-15T16:57:20Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-075-fix-structural-issues-in-project-memory.md
- **Context:** Initial task creation

### 2026-02-16T19:27:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-02-16T19:31:48Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-aaa5b859
- **Timestamp:** 2026-06-02T14:54:24Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
