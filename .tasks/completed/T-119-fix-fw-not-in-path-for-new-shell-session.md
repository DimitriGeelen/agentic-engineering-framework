---
id: T-119
name: Fix fw not in PATH for new shell sessions
description: >
  fw binary at bin/fw is not added to PATH by any shell profile or init script. Every
  new Bash tool call loses PATH, requiring manual export. Fix: context init should
  export PATH, or fw init should add to shell profile. Discovered during T-118 investigation
  — silent bypass of this error happened 3+ times.
status: work-completed
workflow_type: build
owner: agent
tags: []
related_tasks: []
created: 2026-02-17T14:46:58Z
last_update: '2026-08-16T22:24:25Z'
date_finished: 2026-02-17T14:49:18Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:42Z'
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
  - ts: '2026-08-16T22:24:25Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=0 
      (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 (no-signal); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-119: Fix fw not in PATH for new shell sessions

## Context

[Link to design docs, specs, or predecessor tasks]

## Updates

### 2026-02-17T14:46:58Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-119-fix-fw-not-in-path-for-new-shell-session.md
- **Context:** Initial task creation

### 2026-02-17T14:49:18Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5694d0f9
- **Timestamp:** 2026-06-02T14:55:51Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
