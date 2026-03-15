---
id: T-501
name: "Add BASH_DEFAULT_TIMEOUT_MS to claude-fw wrapper"
description: >
  Set BASH_DEFAULT_TIMEOUT_MS=300000 in claude-fw wrapper to prevent timeout on long framework operations (audit, fabric, embeddings). From T-435 GO.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-15T22:32:43Z
last_update: 2026-03-15T22:32:43Z
date_finished: null
---

# T-501: Add BASH_DEFAULT_TIMEOUT_MS to claude-fw wrapper

## Context

From T-435 GO. Prevents Bash timeouts on long operations (audit, fabric, embeddings).

## Acceptance Criteria

### Agent
- [x] `BASH_DEFAULT_TIMEOUT_MS` exported in `bin/claude-fw` before main loop
- [x] Uses `${BASH_DEFAULT_TIMEOUT_MS:-300000}` (user can override)

## Verification

grep -q "BASH_DEFAULT_TIMEOUT_MS" bin/claude-fw

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

### 2026-03-15T22:32:43Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-501-add-bashdefaulttimeoutms-to-claude-fw-wr.md
- **Context:** Initial task creation
