---
id: T-825
name: "Timeline token usage — show per-session token costs in Watchtower /timeline"
description: >
  Inception: Timeline token usage — show per-session token costs in Watchtower /timeline

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-03T23:19:05Z
last_update: 2026-04-13T13:21:39Z
date_finished: 2026-04-13T13:21:39Z
---

# T-825: Timeline token usage — show per-session token costs in Watchtower /timeline

## Problem Statement

Token usage is captured per session (in handover frontmatter: `token_usage: "771.8M tokens, 6290 turns"`) but the Watchtower `/timeline` page doesn't display it. Adding token usage to session cards would show cost trends over time — which sessions were expensive, and whether efficiency is improving.

## Assumptions

1. Handover frontmatter reliably contains `token_usage` for all sessions
2. The string format is parseable (e.g., "771.8M tokens, 6290 turns")
3. Timeline rendering won't be significantly slowed by adding one more field

## Exploration Plan

1. Check data coverage: how many handover files have `token_usage` (5 min)
2. Review timeline.py to confirm minimal change needed (done — 3 lines)
3. Assess rendering impact (6MB page already — one more badge per card is negligible)

## Technical Constraints

None — display-only change, data already exists, no new dependencies.

## Scope Fence

**IN:** Display `token_usage` on timeline session cards
**OUT:** Aggregation charts, cost-per-task calculations, sparklines (future build tasks)

## Acceptance Criteria

### Agent
- [x] Problem statement validated — data exists in every handover
- [x] Assumptions tested — `token_usage` field present in 100% of recent handovers
- [x] Recommendation written: GO — minimal effort, data available

### Human
- [ ] [REVIEW] Review findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact: `cd /opt/999-Agentic-Engineering-Framework && cat docs/reports/T-825-timeline-token-usage.md`
  2. Evaluate: does adding token usage to the timeline add value?
  3. Decide: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-825 go --rationale "your rationale"`
  **Expected:** Decision recorded
  **If not:** Ask for clarification

## Go/No-Go Criteria

**GO if:**
- Data exists in handover frontmatter (confirmed: 100% coverage)
- Implementation is <30 min (confirmed: ~3 lines in timeline.py + 1 line in template)

**NO-GO if:**
- Data quality is poor or inconsistent
- Timeline rendering becomes too slow

## Recommendation

**GO** — Minimal effort (<30 min), data already available in every handover file, adds meaningful temporal context to token usage visibility. The /costs page provides detailed breakdowns; the timeline adds the trend dimension.

## Verification

<!-- Shell commands that MUST pass before work-completed. One per line.
     Lines starting with # are comments. Empty lines ignored.
     The completion gate runs each command — if any exits non-zero, completion is blocked.
     For inception tasks, verification is often not needed (decisions, not code).
-->

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Decision

**Decision**: GO

**Rationale**: GO — Minimal effort (<30 min), data already available in every handover file, adds meaningful temporal context to token usage visibility. The /costs page provides detailed breakdowns; the timeline adds the trend dimension.

**Date**: 2026-04-13T11:07:33Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-03T23:19:32Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T11:07:33Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** GO — Minimal effort (<30 min), data already available in every handover file, adds meaningful temporal context to token usage visibility. The /costs page provides detailed breakdowns; the timeline adds the trend dimension.

### 2026-04-13T13:21:39Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** T-1226: GO decision already recorded

### 2026-04-13T13:21:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: GO decision recorded via Watchtower
