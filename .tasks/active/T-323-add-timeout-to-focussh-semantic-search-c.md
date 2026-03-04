---
id: T-323
name: "Add timeout to focus.sh semantic search calls"
description: >
  focus.sh memory-recall.py and ask.py calls lack timeouts, causing fw work-on to hang when Ollama/Qdrant is slow. Add 10s timeout.

status: started-work
workflow_type: build
owner: agent
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-03-04T23:02:41Z
last_update: 2026-03-04T23:02:41Z
date_finished: null
---

# T-323: Add timeout to focus.sh semantic search calls

## Context

`fw work-on` and `fw context focus` hang when Ollama/Qdrant is slow. Root cause: `memory-recall.py` and `ask.py` calls in focus.sh have no timeout.

## Acceptance Criteria

### Agent
- [x] `memory-recall.py` call wrapped with `timeout 10`
- [x] `ask.py` call wrapped with `timeout 15`
- [x] Graceful degradation — timeout exits silently (existing `|| true`)

## Verification

# Both timeout commands present in focus.sh
grep -q "timeout 10 python3" agents/context/lib/focus.sh
grep -q "timeout 15 python3" agents/context/lib/focus.sh

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

### 2026-03-04T23:02:41Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-323-add-timeout-to-focussh-semantic-search-c.md
- **Context:** Initial task creation
