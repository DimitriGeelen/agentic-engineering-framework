---
id: T-677
name: "Fix fw init hook merge — pre-existing settings.json blocks framework hooks"
description: >
  Fix fw init hook merge — pre-existing settings.json blocks framework hooks

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-28T20:34:56Z
last_update: 2026-03-28T20:34:56Z
date_finished: null
---

# T-677: Fix fw init hook merge — pre-existing settings.json blocks framework hooks

## Context

Discovered during e2e test with vnx-orchestration (https://github.com/Vinix24/vnx-orchestration). `lib/init.sh:534` skips writing settings.json if the file already exists. Projects with pre-existing Claude Code hooks get zero framework governance hooks.

**Root cause:** `if [ ! -f "$dir/.claude/settings.json" ]` — init only writes hooks to NEW projects. Existing projects keep their original hooks untouched.

**Fix needed:** Merge framework hooks into existing settings.json, preserving the project's original hooks. Back up original first.

## Acceptance Criteria

### Agent
- [ ] `fw init` merges framework hooks into pre-existing settings.json
- [ ] Original project hooks are preserved (not overwritten)
- [ ] Backup of original settings.json created before merge
- [ ] `fw upgrade` also merges hooks (not just init)
- [ ] Test: project with pre-existing hooks gets both sets after init

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
