---
id: T-1250
name: "Fix commit-msg hook YAML shrinkage guard grep -c bug"
description: >
  commit-msg hook line 160 arithmetic fails when grep -c finds 0 matches

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-13T22:33:35Z
last_update: '2026-06-11T22:23:43Z'
date_finished: 2026-04-13T22:36:46Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:43Z'
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
---

# T-1250: Fix commit-msg hook YAML shrinkage guard grep -c bug

## Context

The commit-msg hook's YAML shrinkage guard (T-1243) has an arithmetic bug at line 160.

When `grep -c` finds zero matches it prints "0" and exits 1, then `|| echo 0` appends
another "0", producing a two-line variable. Using this in `$((...))` breaks arithmetic:
`syntax error in expression (error token is "0")`.

Observed on every commit where learnings/patterns/practices.yaml is in the diff.

Fix: remove `|| echo 0` (grep -c always prints 0 on no matches) or use `|| true` which
suppresses the exit code without producing extra output.

Affects: `.git/hooks/commit-msg` and template `agents/git/lib/hooks.sh`.

## Acceptance Criteria

### Agent
- [x] `.git/hooks/commit-msg` YAML shrinkage guard uses `|| true` not `|| echo 0`
- [x] `agents/git/lib/hooks.sh` template has the same fix applied
- [x] Test commit with learnings.yaml modification produces no syntax error

## Verification

# Hook does not use || echo 0 in shrinkage guard (produces multi-line variable)
! grep -A3 "YAML Shrinkage Guard" .git/hooks/commit-msg | grep -q "|| echo 0"
! grep -A3 "YAML Shrinkage Guard" agents/git/lib/hooks.sh | grep -q "|| echo 0"

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

### 2026-04-13T22:33:35Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1250-fix-commit-msg-hook-yaml-shrinkage-guard.md
- **Context:** Initial task creation

### 2026-04-13T22:36:46Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-308e89e2
- **Timestamp:** 2026-06-02T14:56:13Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 2

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 2
     - evidence: `! grep -A3 "YAML Shrinkage Guard" .git/hooks/commit-msg | grep -q "|| echo 0"`
  2. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 3
     - evidence: `! grep -A3 "YAML Shrinkage Guard" agents/git/lib/hooks.sh | grep -q "|| echo 0"`
