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

## Acceptance Criteria

### Agent
- [ ] Make a small, safe change to __PROJECT_NAME__ (typo fix, comment, .gitignore)
- [ ] Commit using `fw git commit -m "T-002: description"`
- [ ] Commit succeeds (hook validates T-002 reference)

## Verification

# Last commit references this task
git log -1 --format=%s | grep -q "T-002"
