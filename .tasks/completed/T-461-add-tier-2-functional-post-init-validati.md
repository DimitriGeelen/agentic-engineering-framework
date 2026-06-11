---
id: T-461
name: "Add Tier 2 functional post-init validation"
description: >
  Extend validate-init.sh with functional checks: hook scripts pass bash -n, all sourced
  dependencies exist, find_task_file() defined before use, first task creation succeeds
  without stdin, fw doctor passes, fw audit structure section passes. These run at
  end of init and catch the class of bugs found in Spike 4.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [init, validation]
components: []
related_tasks: []
created: 2026-03-12T17:00:57Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-14T10:25:49Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:24:22Z'
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

# T-461: Add Tier 2 functional post-init validation

## Context

Add Tier 2 functional checks to validate-init.sh. Goes beyond "file exists" to "file works": git hooks pass `bash -n`, settings.json hook paths resolve, CLAUDE.md has key sections, `fw doctor` passes. Re-add validation call to init.sh (removed in T-459 for the old tier-1-only version).

## Acceptance Criteria

### Agent
- [x] validate-init.sh has functional checks section (bash -n on hooks, settings.json paths, CLAUDE.md sections, task frontmatter)
- [x] init.sh calls validate-init.sh again (post-init validation restored)
- [x] validate-init.sh passes `bash -n` syntax check
- [x] Functional checks run successfully on the framework repo itself (5/5 Tier 2 pass, correctly flags T-464 broken frontmatter)

## Verification

# validate-init.sh has functional checks
grep -q 'Tier 2' lib/validate-init.sh
grep -q 'bash -n' lib/validate-init.sh
# init.sh calls validation again
grep -q 'validate-init' lib/init.sh
# Syntax OK
bash -n lib/validate-init.sh
bash -n lib/init.sh

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

### 2026-03-12T17:00:57Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-461-add-tier-2-functional-post-init-validati.md
- **Context:** Initial task creation

### 2026-03-14T10:23:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-14T10:25:49Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-6f7ebf9d
- **Timestamp:** 2026-06-02T15:02:58Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
