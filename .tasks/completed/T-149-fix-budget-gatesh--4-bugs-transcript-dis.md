---
id: T-149
name: "Fix budget-gate.sh — 4 bugs: transcript discovery, pre-compact reset, stale
  fail-open, project isolation"
description: >
  Fix budget-gate.sh — 4 bugs: transcript discovery, pre-compact reset, stale fail-open,
  project isolation

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
related_tasks: []
created: 2026-02-18T11:52:32Z
last_update: '2026-08-16T22:24:34Z'
date_finished: 2026-02-18T11:55:04Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:34Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-149: Fix budget-gate.sh — 4 bugs: transcript discovery, pre-compact reset, stale fail-open, project isolation

## Context

Investigation of sprechloop emergency handover burst (T-148/L-050) revealed budget-gate.sh has 4 bugs that make multi-project budget monitoring non-functional. Also found post-compact-resume.sh used FRAMEWORK_ROOT instead of PROJECT_ROOT, injecting wrong context after compaction.

## Acceptance Criteria

- [x] Bug 1: Transcript discovery scoped to project's Claude Code directory (not global search)
- [x] Bug 2: pre-compact.sh resets PROJECT_ROOT counter/status (not FRAMEWORK_ROOT)
- [x] Bug 3: Stale critical status still blocks (no fail-open at critical)
- [x] Bug 4: post-compact-resume.sh uses PROJECT_ROOT for handover/tasks/git reads
- [x] Allowed commands (git commit, fw handover, Read) pass through at critical level

## Verification

# Bug 1: transcript discovery uses PROJECT_DIR_NAME scoping
grep -q "PROJECT_DIR_NAME" agents/context/budget-gate.sh
# Bug 2: pre-compact resets PROJECT_ROOT paths
grep -q 'PROJECT_ROOT.*budget-gate-counter' agents/context/pre-compact.sh
# Bug 3: stale critical still enforces
grep -q 'STATUS_LEVEL.*critical' agents/context/budget-gate.sh
# Bug 4: post-compact-resume uses PROJECT_ROOT
grep -q 'PROJECT_ROOT.*FRAMEWORK_ROOT' agents/context/post-compact-resume.sh
# All scripts parse cleanly
bash -n agents/context/budget-gate.sh
bash -n agents/context/pre-compact.sh
bash -n agents/context/post-compact-resume.sh

## Updates

### 2026-02-18T11:52:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-149-fix-budget-gatesh--4-bugs-transcript-dis.md
- **Context:** Initial task creation

### 2026-02-18T11:55:04Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f753f0c1
- **Timestamp:** 2026-06-02T14:57:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
