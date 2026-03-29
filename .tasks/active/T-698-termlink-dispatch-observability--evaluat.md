---
id: T-698
name: "TermLink dispatch observability — evaluate interactive vs headless worker mode for human observation"
description: >
  Inception: TermLink dispatch observability — evaluate interactive vs headless worker mode for human observation

status: captured
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: [T-697, T-696, T-679, T-577]
created: 2026-03-29T08:18:33Z
last_update: 2026-03-29T08:18:33Z
date_finished: null
---

# T-698: TermLink dispatch observability — evaluate interactive vs headless worker mode for human observation

## Problem Statement

`fw termlink dispatch` uses `claude -p --output-format text > result.md` — a headless pipe. The human cannot observe the worker in real time. `termlink attach` shows the shell that launched it, not the Claude session's tool calls or reasoning.

**Discovery:** T-697 (KCP deep-dive) — human asked to see what the worker was doing. Mirror terminal showed nothing useful because Claude's output was piped to a file. The worker was clearly working (pstree showed active child processes, tasks were being completed) but the human had zero visibility.

**Why now:** Path C workflow (T-696) requires human trust in an autonomous worker operating in an external project. Observability is a UX requirement, not a nice-to-have.

**Why headless may have been chosen:** There may be good reasons — `claude -p` is simpler than interactive mode, output capture is reliable, and TermLink PTY session management for interactive Claude may be complex. This inception explores the tradeoffs.

## Assumptions

A-1: Interactive `claude` in a TermLink PTY session is technically feasible (vs. `claude -p`)
A-2: The human wants to see tool calls and reasoning, not just final output
A-3: There's a middle ground (e.g., `claude -p` with streaming + tee) that preserves reliability while adding observability
A-4: The current headless approach was an engineering convenience, not a deliberate design choice

## Exploration Plan

1. **Spike 1:** Research why `run.sh` uses `claude -p` — check T-522, T-577 for original design decisions
2. **Spike 2:** Test alternatives — `claude -p` with `tee`, interactive `claude` in PTY, streaming JSON
3. **Spike 3:** Evaluate tradeoffs — reliability, output capture, human UX, context cost

## Scope Fence

**IN:** Evaluate dispatch observability options, prototype one alternative
**OUT:** Rebuilding the entire dispatch system, TermLink product changes

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Current headless design rationale documented
- [ ] At least 2 alternatives evaluated with tradeoffs
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Read the research artifact and recommendation in this task
  2. Evaluate go/no-go criteria against findings
  3. Run: `cd /opt/999-Agentic-Engineering-Framework && bin/fw inception decide T-698 go|no-go --rationale "your rationale"`
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- An alternative exists that adds observability without breaking output capture reliability
- Implementation is bounded (< 1 session)

**NO-GO if:**
- All alternatives compromise reliability (output capture, error handling)
- Observability requires TermLink product changes we can't control

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

<!-- Filled at completion via: fw inception decide T-XXX go|no-go --rationale "..." -->

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->
