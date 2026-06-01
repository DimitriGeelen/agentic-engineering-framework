---
id: T-1147
name: "T-1104 build: fw doctor doc-drift check — warn when fw subcommands missing from CLAUDE.md Quick Reference"
description: >
  T-1104 build: fw doctor doc-drift check — warn when fw subcommands missing from CLAUDE.md Quick Reference

status: work-completed
workflow_type: build
owner: agent
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-12T10:15:49Z
last_update: 2026-04-12T10:30:07Z
date_finished: 2026-04-12T10:30:07Z
---

# T-1147: T-1104 build: fw doctor doc-drift check — warn when fw subcommands missing from CLAUDE.md Quick Reference

## Context

From T-1104 inception (GO). Add doc-drift check to `fw doctor`.

## Acceptance Criteria

### Agent
- [x] fw doctor includes doc-drift check comparing bin/fw subcommands vs CLAUDE.md Quick Reference
- [x] Missing subcommands produce WARN (not FAIL)
- [x] fw doctor still passes overall

## Verification

bash -c 'bin/fw doctor 2>&1 | grep -qi "doc\|drift\|reference"'

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

### 2026-04-12T10:15:49Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1147-t-1104-build-fw-doctor-doc-drift-check--.md
- **Context:** Initial task creation

### 2026-04-12T10:30:07Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
