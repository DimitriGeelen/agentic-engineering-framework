---
id: T-835
name: "Watchtower stale task dashboard — notification, batch review, and auto-resolution for 54+ pending human review tasks"
description: >
  Inception: Watchtower stale task dashboard — notification, batch review, and auto-resolution for 54+ pending human review tasks

status: work-completed
workflow_type: inception
owner: human
horizon: null
tags: []
components: []
related_tasks: []
created: 2026-04-04T12:41:09Z
last_update: 2026-04-13T13:21:40Z
date_finished: 2026-04-13T13:21:40Z
---

# T-835: Watchtower stale task dashboard — notification, batch review, and auto-resolution for 54+ pending human review tasks

## Problem Statement

77 work-completed tasks with 79 unchecked Human ACs. Backlog growing at ~7/day, 0 reviewed/day. All review tooling is single-task-oriented — clearing the backlog requires 2-3 hours of manual clicking.

## Exploration Plan

3 parallel TermLink workers:
- Agent A: Backlog analysis (categories, verifiability, age distribution)
- Agent B: Existing tooling audit (gaps, quick wins)
- Agent C: Design options (batch approval, auto-close, digest notification)

## Scope Fence

IN: Clearing the 77-task backlog efficiently, auto-closing RUBBER-STAMP tasks
OUT: New Watchtower pages (Option A deferred to separate build task)

## Acceptance Criteria

### Agent
- [x] Problem statement validated (77 tasks, 79 unchecked ACs)
- [x] 3 TermLink workers completed research
- [x] Recommendation written: GO — Option B (auto-close RUBBER-STAMP) first

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-XXX go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- Option B effort justified (S, 1-2h) relative to 31+ tasks cleared
- No sovereignty violation from auto-close (RUBBER-STAMP only, dry-run default)

**NO-GO if:**
- Human prefers manual review of all tasks (no automation)
- Backlog is intentionally maintained as a review queue

## Recommendation

- **Recommendation:** GO
- **Rationale:** 77 tasks in stale backlog, growing at 7/day. Option B auto-closes 31 RUBBER-STAMP tasks (S effort). Option A handles remaining 48 REVIEW tasks with batch UI (M effort).
- **Evidence:** 3 TermLink research reports in `docs/reports/T-835-agent-{a,b,c}-*.md`
- **Build tasks after GO:** T-836 (verify-acs --auto-close), T-837 (batch approval page)

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

**Rationale**: - Recommendation: GO
- Rationale: 77 tasks in stale backlog, growing at 7/day. Option B auto-closes 31 RUBBER-STAMP tasks (S effort). Option A handles remaining 48 REVIEW tasks with batch UI (M effort).
- Evidence: 3 TermLink research reports in `docs/reports/T-835-agent-{a,b,c}-.md`
- Build tasks after GO: T-836 (verify-acs --auto-close), T-837 (batch approval page)

**Date**: 2026-04-13T11:07:46Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-04T12:41:58Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-12T09:26:20Z — status-update [task-update-agent]
- **Change:** horizon: now → next
- **Change:** status: started-work → captured (auto-sync)

### 2026-04-13T11:07:42Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: 77 tasks in stale backlog, growing at 7/day. Option B auto-closes 31 RUBBER-STAMP tasks (S effort). Option A handles remaining 48 REVIEW tasks with batch UI (M effort).
- Evidence: 3 TermLink research reports in `docs/reports/T-835-agent-{a,b,c}-.md`
- Build tasks after GO: T-836 (verify-acs --auto-close), T-837 (batch approval page)

### 2026-04-13T11:07:46Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** - Recommendation: GO
- Rationale: 77 tasks in stale backlog, growing at 7/day. Option B auto-closes 31 RUBBER-STAMP tasks (S effort). Option A handles remaining 48 REVIEW tasks with batch UI (M effort).
- Evidence: 3 TermLink research reports in `docs/reports/T-835-agent-{a,b,c}-.md`
- Build tasks after GO: T-836 (verify-acs --auto-close), T-837 (batch approval page)

### 2026-04-13T13:21:40Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)
- **Reason:** T-1226: GO decision already recorded

### 2026-04-13T13:21:40Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** T-1226: GO decision recorded via Watchtower

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1323a323
- **Timestamp:** 2026-06-02T15:05:09Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
