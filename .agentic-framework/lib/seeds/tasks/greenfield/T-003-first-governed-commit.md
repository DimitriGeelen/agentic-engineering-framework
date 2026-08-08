---
id: T-003
name: "First governed commit for __PROJECT_NAME__"
description: >
  Create the initial project structure and make the first governed commit. This validates
  the governance loop: task reference → commit-msg hook → post-commit advisory.
status: captured
workflow_type: build
owner: agent
horizon: now
tags: [onboarding]
components: []
related_tasks: []
created: __DATE__
last_update: __DATE__
date_finished: null
---

# T-003: First governed commit for __PROJECT_NAME__

## Context

Create initial project files (README, directory structure, entry point) and commit through the framework. The commit-msg hook validates the task reference.

## For the Operator

**What is happening:** the first commit that goes through the framework's own git hooks.
Note the message format — `T-003: Initial project structure`. That `T-003:` prefix is not
decoration.

**Why it matters to you:** every commit in this project must name the task it belongs to,
and a hook refuses the commit if it does not. Six months from now, `git log` will answer
*why does this line exist* by pointing at a task file that still holds the reasoning, the
acceptance criteria, and the decisions made along the way. That link is the entire point,
and it only survives if it is enforced on every commit rather than remembered on most.

**What you can do meanwhile:** nothing required. If you are curious, run `git log --oneline`
after this step and notice that the history has become an index.

**Go deeper:** `fw corpus explain aef-task-lifecycle` — the states a task moves through, and
which gates guard each transition.

## Acceptance Criteria

### Agent
- [ ] Create initial project structure (README.md, src/ or appropriate dirs)
- [ ] Commit using `fw git commit -m "T-003: Initial project structure"`
- [ ] Commit succeeds (hook validates T-003 reference)

## Verification

# Last commit references this task
git log -1 --format=%s | grep -q "T-003"

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
