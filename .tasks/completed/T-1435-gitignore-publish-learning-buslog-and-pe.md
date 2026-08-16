---
id: T-1435
name: "gitignore publish-learning-bus.log and pending-updates.yaml (runtime working-memory
  files)"
description: >
  gitignore publish-learning-bus.log and pending-updates.yaml (runtime working-memory
  files)

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-24T16:24:04Z
last_update: '2026-08-16T22:24:32Z'
date_finished: 2026-04-24T16:24:51Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:48Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-ORCH=0 (no-signal); 
      F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:24:32Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 0
      D3: 0
      D4: 4
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=2 (body:learning-ref); D2=0 (no-signal); D3=0 (no-signal); 
      D4=4 (body:cross-machine); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1435: gitignore publish-learning-bus.log and pending-updates.yaml (runtime working-memory files)

## Context

Two runtime-generated files under `.context/working/` appear as untracked in every
session, polluting `git status`:

- `.publish-learning-bus.log` — append-only activity log from
  `lib/publish-learning-to-bus.sh` (one line per `channel:learnings` broadcast)
- `pending-updates.yaml` — per-machine state for `fw pending` (blocked cross-project
  ops like U-001 waiting on TOFU clears)

Both are machine-local, regenerated on demand, and have never been tracked in git
(verified via `git log --all --oneline -- <file>`). The existing
`.context/working/.gitignore` already ignores similar volatile files
(`.tool-counter`, `session.yaml`, `focus.yaml`, `tier0-approval`) — just missing
these two newer runtime artifacts.

L-176 warns against gitignoring `.context/` or `.tasks/` wholesale — this change
adds two targeted entries inside the existing working-memory .gitignore, which is
the established pattern.

## Acceptance Criteria

### Agent
- [x] `.context/working/.gitignore` contains `.publish-learning-bus.log` entry
- [x] `.context/working/.gitignore` contains `pending-updates.yaml` entry
- [x] `git status --short` no longer shows either file as `??` untracked

## Verification

grep -q '^.publish-learning-bus.log$' .context/working/.gitignore
grep -q '^pending-updates.yaml$' .context/working/.gitignore
! git status --short | grep -q '.publish-learning-bus.log'
! git status --short | grep -q 'pending-updates.yaml'

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

### 2026-04-24T16:24:04Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1435-gitignore-publish-learning-buslog-and-pe.md
- **Context:** Initial task creation

### 2026-04-24T16:24:51Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-b89f2d96
- **Timestamp:** 2026-06-02T14:57:27Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `! git status --short | grep -q '.publish-learning-bus.log'`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `! git status --short | grep -q 'pending-updates.yaml'`
