---
id: T-1474
name: "fw push skips all remotes when no origin exists (handover.sh:847 mirror-skip
  logic)"
description: >
  Bug in agents/handover/handover.sh:847. When repo has >1 remote AND none is named
  `origin`, the mirror-skip guard skips ALL remotes. Repro: this repo has `github`
  + `onedev` (no `origin`); both skipped each handover citing fictional
  PushRepository mirroring. User compensates with manual `git push github master &&
  git push onedev master`. Recurred S-2026-0425-2145 and S-2026-0425-2155.

status: work-completed
workflow_type: build
owner: agent
horizon: null
components: [agents/handover/handover.sh, 
      tests/unit/handover_push_no_origin.bats]
related_tasks: [T-1255, T-1144, T-1277]
created: 2026-04-25T20:01:40Z
last_update: '2026-06-11T22:23:49Z'
date_finished: 2026-04-25T20:04:08Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:49Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 1
      F-ORCH: 0
      F3: 0
      F1: 1
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=1 (body:episodic-only); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=1 
      (body/components:context-fabric-incidental); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1474: fw push skips all remotes when no origin exists (handover.sh:847)

## Context

T-1255 introduced the mirror-skip on the assumption that OneDev's `PushRepository`
mirrors `origin` → `github`, so the agent only pushes to `origin`. But the actual
guard condition (`remote_name != "origin"`) skips every remote when no remote is
named `origin`.

Framework repo state: `github` + `onedev` configured directly (both fetch+push),
no `origin`. Handover skips both. User compensates manually.

## Fix

Compute `_has_origin` once. Skip mirrors only when `_has_origin` is true. When no
origin exists (legitimate multi-remote without canonical), push all.

## Acceptance Criteria

### Agent
- [x] handover.sh skips non-origin remotes ONLY when `origin` is configured
- [x] When no `origin` exists, all remotes receive the push (preserves T-1144)
- [x] Mirror-skip behavior preserved when `origin` DOES exist (T-1255 invariant)
- [x] Bats test `tests/unit/handover_push_no_origin.bats` exercises both branches
- [x] `bash -n agents/handover/handover.sh` passes

## Verification

bash -n agents/handover/handover.sh
bats tests/unit/handover_push_no_origin.bats

## Updates

### 2026-04-25T20:01:40Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1474-fw-push-skips-all-remotes-when-no-origin.md
- **Context:** Initial task creation

## Reviewer Verdict (v1.5)

- **Scan ID:** R-5242486d
- **Timestamp:** 2026-06-02T14:57:43Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-04-25T20:04:08Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
