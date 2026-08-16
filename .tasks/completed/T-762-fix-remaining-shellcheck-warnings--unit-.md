---
id: T-762
name: "Fix remaining shellcheck warnings + unit tests for episodic, init, safe-commands
  libs"
description: >
  Fix remaining shellcheck warnings + unit tests for episodic, init, safe-commands
  libs

status: work-completed
workflow_type: test
owner: agent
horizon:
tags: []
components: []
related_tasks: []
created: 2026-03-30T11:53:30Z
last_update: '2026-08-16T22:25:39Z'
date_finished: 2026-03-30T12:14:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:29Z'
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
  - ts: '2026-08-16T22:25:39Z'
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

# T-762: Fix remaining shellcheck warnings + unit tests for episodic, init, safe-commands libs

## Context

Continuation of T-760/T-761 shellcheck cleanup and T-757/T-758 unit test expansion. Two shellcheck false positives remain in lib/colors.sh and lib/upgrade.sh. Three context libs (episodic.sh, init.sh, safe-commands.sh) have no unit tests.

## Acceptance Criteria

### Agent
- [x] Fix shellcheck SC2034 warning in lib/colors.sh (BOLD variable)
- [x] Fix shellcheck SC2034 warning in lib/upgrade.sh (framework_resume variable)
- [x] Unit tests for agents/context/lib/safe-commands.sh (5+ tests)
- [x] Unit tests for agents/context/lib/init.sh (5+ tests)
- [x] Unit tests for agents/context/lib/episodic.sh (5+ tests)
- [x] All new tests pass
- [x] Clean up 29 onboarding test task artifacts from active/

## Verification

test "$(shellcheck lib/colors.sh lib/upgrade.sh 2>&1 | grep -c 'warning')" = "0"
bats tests/unit/context_safe_commands.bats
bats tests/unit/context_init.bats
bats tests/unit/context_episodic.bats

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

### 2026-03-30T11:53:30Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-762-fix-remaining-shellcheck-warnings--unit-.md
- **Context:** Initial task creation

### 2026-03-30T12:14:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-ca1fe674
- **Timestamp:** 2026-06-02T15:04:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
