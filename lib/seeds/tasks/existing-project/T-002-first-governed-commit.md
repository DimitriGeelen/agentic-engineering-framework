---
id: T-002
name: "First governed commit for __PROJECT_NAME__"
description: >
  Make a small change (fix a typo, update a comment, add a .gitignore entry) and commit
  it using the framework's git agent. This validates the full commit flow: task reference,
  commit-msg hook, post-commit advisory.
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

# T-002: First governed commit for __PROJECT_NAME__

## Context

Make any small change and commit it through the framework. The commit-msg hook will validate the task reference. This proves the governance loop works end to end.

**Note:** Do not add `.context/` or `.tasks/` to `.gitignore` — these are managed by the framework and may need to be committed (e.g., handovers). Safe changes: fix a typo in README, add a code comment, or add build artifacts to `.gitignore`.

## For the Operator

**What is happening:** the agent makes a deliberately small, safe change to
__PROJECT_NAME__ and commits it through the framework's git hooks. Small on purpose — the
point is to exercise the path, not to change anything you care about.

**Why it matters to you:** note the message format, `T-002: description`. That prefix is
enforced; a hook refuses commits without it. From here on, `git log` answers *why does this
line exist* by pointing at a task file that still holds the reasoning, the acceptance
criteria, and the decisions. On an existing codebase you will have two eras in your
history — before and after this commit. Only the second one is self-explaining.

**What you can do meanwhile:** nothing required. If the agent proposes a change you would
rather it not touch, say so — "small and safe" is its judgement, and yours overrides.

**Go deeper:** `fw corpus explain aef-task-lifecycle` — the states a task moves through, and
which gates guard each transition.

## Acceptance Criteria

### Agent
- [ ] Make a small, safe change to __PROJECT_NAME__ (typo fix, comment, .gitignore)
- [ ] Commit using `fw git commit -m "T-002: description"`
- [ ] Commit succeeds (hook validates T-002 reference)

## Verification

# Last commit references this task
git log -1 --format=%s | grep -q "T-002"
