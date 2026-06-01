---
id: T-864
name: "Inception: Record task execution stats (timing, token cost, complexity) in task files"
description: >
  Inception: Record task execution stats (timing, token cost, complexity) in task files

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T20:36:33Z
last_update: 2026-04-13T06:23:29Z
date_finished: 2026-04-04T21:56:57Z
---

# T-864: Inception: Record task execution stats (timing, token cost, complexity) in task files

## Problem Statement

Is it sensible and achievable to record execution statistics (timing, token cost, complexity metrics) directly in task files? Currently: session-level metrics exist in handovers but per-task cost/effort data is not tracked. If task files included stats like tokens consumed, time spent, commits made, and lines changed — we could answer questions like "how much did this feature cost?" and "what's our average build task effort?"

**Data sources available:** JSONL transcripts (tokens), git log (commits, lines, time), task frontmatter (created/finished dates), episodic summaries.

## Assumptions

- A1: Per-task token usage can be derived from JSONL transcripts by filtering for tool calls within focus windows
- A2: Task frontmatter can hold structured stats without breaking existing parsers
- A3: The stats are useful for planning (effort prediction) and retrospectives
- A4: Auto-populating stats at task completion is achievable without excessive transcript parsing cost

## Exploration Plan

1. **Research**: What stats are already available at task completion time?
2. **Prototype**: Add a `## Stats` section to update-task.sh on work-completed
3. **Evaluate**: Is the data accurate enough to be useful?

## Technical Constraints

- JSONL transcripts may be large (500MB+) — parsing must be bounded
- Stats section must be optional (backward compatible)
- Must not slow down `fw task update --status work-completed`

## Scope Fence

**IN scope:** Feasibility of per-task stats, what data to record, where to store it
**OUT of scope:** Watchtower visualization of per-task stats, cross-task analytics

## Acceptance Criteria

### Agent
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Per-task stats can be derived without expensive transcript parsing (>5s)
- Stats provide actionable data (effort prediction, cost tracking)

**NO-GO if:**
- Accurate per-task token attribution is not possible (sessions span multiple tasks)
- Stats add >2s to task completion workflow

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

**Decision**: NO-GO

**Rationale**: Episodic summaries already capture 80% of desired stats

**Date**: 2026-04-05T05:39:24Z

## Recommendation

- **Recommendation:** NO-GO
- **Rationale:** Episodic summaries already capture 80% of desired stats. Per-task token cost attribution is inaccurate and expensive. Session-level costs divided by tasks-per-session is a reasonable approximation.
- **Evidence:**
  - Episodic T-043 has: wall_clock_minutes: 53, commits: 1, files_changed: 85, lines_added: 4043
  - JSONL transcript: 68MB — parsing takes 5-30s
  - `fw metrics predict --type build` already works from episodic data
  - No mechanism to tag JSONL entries with task IDs at protocol level
- **Research artifact:** `docs/reports/T-864-task-execution-stats.md`

## Decision

**Decision**: NO-GO

**Rationale**: Episodic summaries already capture 80% of desired stats

**Date**: 2026-04-05T05:39:24Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T20:44:57Z — status-update [task-update-agent]
- **Change:** status: started-work → captured

### 2026-04-04T21:53:01Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-04T21:56:56Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** - Recommendation: NO-GO
- Rationale: Episodic summaries already capture 80% of desired stats. Per-task token cost attribution is inaccurate and expensive. Session-level costs divided by tasks-per-session is a reasonable approximation.
- Evidence:
  - Episodic T-043 has: wall_clock_minutes: 53, commits: 1, files_changed: 85, lines_added: 4043
  - JSONL transcript: 68MB — parsing takes 5-30s
  - `fw metrics predict --type build` already works from episodic data
  - No mechanism to tag JSONL ent...

### 2026-04-04T21:56:57Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: NO-GO

### 2026-04-05T05:39:24Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** NO-GO
- **Rationale:** Episodic summaries already capture 80% of desired stats

### 2026-04-12T09:27:23Z — status-update [task-update-agent]
- **Change:** horizon: now → next
