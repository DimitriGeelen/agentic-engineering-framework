---
id: T-217
name: "Enforce sub-agent output discipline: prompt template + bus integration"
description: >
  Enforce sub-agent output discipline: prompt template + bus integration

status: work-completed
workflow_type: build
owner: agent
horizon: now
tags: []
related_tasks: []
created: 2026-02-20T08:41:36Z
last_update: 2026-02-20T08:44:24Z
date_finished: 2026-02-20T08:44:24Z
---

# T-217: Enforce sub-agent output discipline: prompt template + bus integration

## Context

Sub-agents return full content blobs instead of writing to disk + returning summaries. T-073 caused 177K token spike. Multiple sessions crashed from agent result ingestion. The dispatch protocol in CLAUDE.md exists but agents don't read CLAUDE.md — they only get their prompt.

## Acceptance Criteria

### Agent
- [x] Mandatory preamble file created at agents/dispatch/preamble.md
- [x] Preamble includes output rules, file path convention, response length limit
- [x] Auto-memory updated with dispatch rules (loaded every session)
- [x] Test agent dispatched with preamble — wrote 25KB to file, returned 4 lines

## Verification

# Preamble file exists and has output rules
grep -q "MANDATORY, NON-NEGOTIABLE" agents/dispatch/preamble.md
# Memory file has dispatch rules
grep -q "Sub-Agent Dispatch Rules" /root/.claude/projects/-opt-999-Agentic-Engineering-Framework/memory/MEMORY.md
# Preamble includes file write instruction
grep -q "Write all detailed output to disk" agents/dispatch/preamble.md

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

### 2026-02-20T08:41:36Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-217-enforce-sub-agent-output-discipline-prom.md
- **Context:** Initial task creation

### 2026-02-20T08:44:24Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
