---
id: T-677
name: "Fix fw init hook merge — pre-existing settings.json blocks framework hooks"
description: >
  Fix fw init hook merge — pre-existing settings.json blocks framework hooks

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-28T20:34:56Z
last_update: '2026-08-16T22:25:37Z'
date_finished: 2026-03-28T20:59:46Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:27Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-ORCH: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-ORCH=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
  - ts: '2026-08-16T22:25:37Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 0
      F-RECALL: 0
      F-AUTONOMY: 0
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=0 (no-signal); F-RECALL=0 (no-signal); F-AUTONOMY=0 
      (no-signal); F3=0 (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-677: Fix fw init hook merge — pre-existing settings.json blocks framework hooks

## Context

Discovered during e2e test with vnx-orchestration (https://github.com/Vinix24/vnx-orchestration). `lib/init.sh:534` skips writing settings.json if the file already exists. Projects with pre-existing Claude Code hooks get zero framework governance hooks.

**Root cause:** `if [ ! -f "$dir/.claude/settings.json" ]` — init only writes hooks to NEW projects. Existing projects keep their original hooks untouched.

**Fix needed:** Back up existing settings.json, then overwrite with framework hooks. The framework's governance is authoritative for governed projects.

## Acceptance Criteria

### Agent
- [x] `fw init` replaces hooks in pre-existing settings.json with framework hooks
- [x] Backup of original settings.json created before replace (.pre-fw)
- [x] Test: vnx-orchestration with 8 pre-existing hooks → framework hooks applied, backup preserved

## Verification

# init.sh has merge logic (not just skip-if-exists)
grep -q "merge" lib/init.sh || grep -q "existing.*hook" lib/init.sh

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

### 2026-03-28T20:34:56Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-677-fix-fw-init-hook-merge--pre-existing-set.md
- **Context:** Initial task creation

### 2026-03-28T20:59:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-d03a86d7
- **Timestamp:** 2026-06-02T15:04:17Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 1

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `grep -q "merge" lib/init.sh || grep -q "existing.*hook" lib/init.sh`
