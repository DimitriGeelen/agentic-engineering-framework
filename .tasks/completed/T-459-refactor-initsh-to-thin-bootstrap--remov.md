---
id: T-459
name: "Refactor init.sh to thin bootstrap — remove dynamic task creation"
description: >
  Keep bootstrap steps in init.sh: create dirs, copy templates, create .framework.yaml,
  copy curated seeds, generate provider config, context init. Remove: dynamic create-task.sh
  calls, git hook install, PATH setup, post-init validation. These become onboarding
  task templates (separate task). Init just copies template tasks from lib/seeds/tasks/
  into .tasks/active/ with __PROJECT_NAME__ and __DATE__ substitution.

status: work-completed
workflow_type: build
owner: agent
horizon:
tags: [init, refactor, architecture]
components: []
related_tasks: []
created: 2026-03-12T17:00:48Z
last_update: '2026-06-11T22:24:22Z'
date_finished: 2026-03-13T10:00:07Z
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

# T-459: Refactor init.sh to thin bootstrap — remove dynamic task creation

## Context

Make init.sh a thin, deterministic bootstrap. Remove dynamic `create-task.sh` calls, git hook install, PATH setup, and post-init validation. These move to onboarding tasks (T-460). Init becomes: create dirs, copy templates/seeds, generate provider config, context init.

## Acceptance Criteria

### Agent
- [x] No `create-task.sh` calls in init.sh (dynamic task creation removed)
- [x] No `install-hooks` call in init.sh (git hook install removed)
- [x] No PATH/symlink setup in init.sh
- [x] No `validate-init.sh` call in init.sh (post-init validation removed)
- [x] Init still creates directory structure, copies seeds, generates provider config, runs context init
- [x] Init parses cleanly (bash -n check passes)

## Verification

# No dynamic task creation
test "$(grep -c 'create-task.sh' lib/init.sh)" = "0"
# No git hook install
test "$(grep -c 'install-hooks' lib/init.sh)" = "0"
# No PATH/symlink setup
test "$(grep -c '/usr/local/bin' lib/init.sh)" = "0"
# No validate-init call
test "$(grep -c 'validate-init' lib/init.sh)" = "0"
# Still creates dirs
grep -q 'mkdir -p.*\.tasks/active' lib/init.sh
# Still copies seeds
grep -q 'seeds/decisions.yaml' lib/init.sh
# Still generates provider config
grep -q 'generate_claude_md' lib/init.sh
# Still runs context init
grep -q 'context_init_script.*init' lib/init.sh
# Syntax check
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

### 2026-03-12T17:00:48Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-459-refactor-initsh-to-thin-bootstrap--remov.md
- **Context:** Initial task creation

### 2026-03-13T09:58:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-03-13T10:00:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed

## Reviewer Verdict (v1.5)

- **Scan ID:** R-f6055ad5
- **Timestamp:** 2026-06-02T15:02:57Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
