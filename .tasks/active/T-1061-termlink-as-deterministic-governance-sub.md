---
id: T-1061
name: "TermLink as deterministic governance substrate — PTY-level enforcement vs Claude Code hooks, custom terminal evaluation, multi-LLM routing"
description: >
  Inception: TermLink as deterministic governance substrate — PTY-level enforcement vs Claude Code hooks, custom terminal evaluation, multi-LLM routing

status: started-work
workflow_type: inception
owner: human
horizon: now
tags: []
components: []
related_tasks: []
created: 2026-04-07T20:51:33Z
last_update: 2026-04-07T20:52:45Z
date_finished: null
---

# T-1061: TermLink as deterministic governance substrate — PTY-level enforcement vs Claude Code hooks, custom terminal evaluation, multi-LLM routing

## Problem Statement

Can TermLink's PTY ownership replace Claude Code hooks as the enforcement layer for the prime directive ("nothing gets done without a task")? PTY-level enforcement is deterministic (byte stream must pass through TermLink) while hook-level enforcement is stochastic (callbacks fire if the API works). Also explores: custom terminal options, multi-LLM routing through TermLink hub, and the four-dimension agent architecture (task/context/component/execution).

## Research Artifact

`docs/reports/T-1061-termlink-governance-substrate.md`

## Assumptions

1. PTY-level interception provides true deterministic enforcement (no bypass path)
2. Claude Code's output stream contains parseable tool call signals at VT sequence level
3. WezTerm or Zellij can be adapted for task-aware chrome without building a full emulator
4. Multi-LLM routing at the hub level is architecturally sound
5. Metadata collection is "free" since all events pass through the hub

## Exploration Plan

1. **Spike 1:** Parse Claude Code PTY output to identify tool call signals (2h)
2. **Spike 2:** Evaluate WezTerm Lua API for task state display (2h)
3. **Spike 3:** Prototype multi-LLM routing via TermLink hub (4h)
4. **Research:** Map all 4 dimensions to TermLink capabilities

## Technical Constraints

- TermLink is Rust-based (termlink 0.9.0)
- PTY interception works on Linux/macOS, not Windows
- VT sequence parsing needed for reliable signal detection
- Flow control for true blocking pre-hooks requires proxy PTY layer

## Scope Fence

**IN:** PTY enforcement architecture, custom terminal evaluation, multi-LLM routing design, metadata collection architecture, mapping through four constitutional directives (antifragility, reliability, usability, portability)
**OUT:** Building a terminal emulator, implementing multi-LLM routing, production PTY flow control

## Acceptance Criteria

### Agent
- [ ] Problem statement validated
- [ ] Assumptions tested
- [ ] Recommendation written with rationale

### Human
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- PTY intercept can reliably detect Claude Code tool calls (spike 1 proves it)
- At least one terminal project (WezTerm/Zellij) supports task-aware chrome without major forking
- Multi-LLM routing at hub level doesn't introduce unacceptable latency

**NO-GO if:**
- Claude Code output is too unstructured for reliable PTY parsing
- Custom terminal work exceeds 2 sprints of undifferentiated effort
- PTY flow control for blocking pre-hooks proves architecturally unsound

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).

## Recommendation

<!-- REQUIRED before fw inception decide. Write your recommendation here (T-974).
     Watchtower reads this section — if it's empty, the human sees nothing.
     Format:
     **Recommendation:** GO / NO-GO / DEFER
     **Rationale:** Why (cite evidence from exploration)
     **Evidence:**
     - Finding 1
     - Finding 2
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

### 2026-04-07T20:52:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
