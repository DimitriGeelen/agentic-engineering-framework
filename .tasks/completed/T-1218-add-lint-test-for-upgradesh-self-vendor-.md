---
id: T-1218
name: "Add lint test for upgrade.sh self-vendor mechanism"
description: >
  Add lint test for upgrade.sh self-vendor mechanism

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-13T10:11:23Z
last_update: 2026-04-13T10:13:22Z
date_finished: 2026-04-13T10:13:22Z
---

# T-1218: Add lint test for upgrade.sh self-vendor mechanism

## Context

T-1217 added a self-vendor step to upgrade.sh that syncs `lib/*.sh` to `.agentic-framework/lib/`
before upgrading consumers. Add lint tests to guard this mechanism against removal or regression.

## Acceptance Criteria

### Agent
- [x] Lint test verifies self-vendor code exists in upgrade.sh
- [x] Lint test verifies self-vendor syncs lib/*.sh (not hardcoded list)
- [x] All lint tests pass

## Verification

bats tests/lint/single-vendor-writer.bats

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

### 2026-04-13T10:11:23Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1218-add-lint-test-for-upgradesh-self-vendor-.md
- **Context:** Initial task creation

### 2026-04-13T10:13:22Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
