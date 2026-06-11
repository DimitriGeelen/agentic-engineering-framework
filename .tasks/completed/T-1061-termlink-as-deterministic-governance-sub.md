---
id: T-1061
name: "TermLink as deterministic governance substrate — PTY-level enforcement vs Claude
  Code hooks, custom terminal evaluation, multi-LLM routing"
description: >
  Inception: TermLink as deterministic governance substrate — PTY-level enforcement
  vs Claude Code hooks, custom terminal evaluation, multi-LLM routing

status: work-completed
workflow_type: inception
owner: human
horizon:
tags: []
components: []
related_tasks: []
created: 2026-04-07T20:51:33Z
last_update: '2026-06-11T22:23:38Z'
date_finished: 2026-04-08T05:30:50Z
target_blast_radius: 3   # T-2193 migration default (M=small-subsystem floor)
voi_score: 0.5            # T-2193 migration default (medium)
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:38Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 2
      D2: 2
      D3: 2
      D4: 2
      F-RECALL: 2
      F-ORCH: 2
      F3: 2
      F1: 2
      F2: 2
    rationale: D1=2 (no-signal); D2=2 (no-signal); D3=2 (no-signal); D4=2 
      (no-signal); F-RECALL=2 (no-signal); F-ORCH=2 (no-signal); F3=2 
      (no-signal); F1=2 (no-signal); F2=2 (no-signal)
    rubric_sha: e4a00f38e801
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
- [x] Problem statement validated
- [x] Assumptions tested
- [x] Recommendation written with rationale

### Human
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO

**Rationale:** TermLink's governance substrate thesis is validated — but the mechanism is MCP + hub orchestrator + data plane, NOT PTY byte stream parsing. The TermLink project itself reviewed the document (19KB, code-path-specific corrections) and confirmed: governance at the structured API layer is feasible and architecturally correct. PTY parsing is rejected as infeasible (deadlock risk, terminal emulator trap, coupled to output format).

**Evidence:**
- TermLink already has governance primitives: bypass registry, route cache, circuit breaker (`bypass.rs`, `route_cache.rs`, `circuit_breaker.rs`)
- MCP server (4378 lines, 40+ tools) is loaded INTO Claude Code — governance checks can be added at MCP tool level (structured, reliable, blockable)
- `orchestrator.route` chain (`router.rs:640-1000+`) already implements discover -> forward -> failover -> bypass registry -> route cache -> circuit breaker
- PTY read loop (`pty.rs:171-219`) is fire-and-forget — no buffer/pause API exists, pre-hook via buffer hold is architecturally unsound
- Task-aware terminal chrome via WezTerm Lua plugin requires zero new TermLink code (3-6 weeks)
- 15 Claude Code hooks have documented gaps (G-011, G-015, G-017) that MCP-level governance can address for cross-session operations

**Implementation path:** Phase 1 WezTerm chrome (3-6 weeks) -> Phase 2 MCP governance (2-4 weeks) -> Phase 3 orchestrator routing (2-4 weeks) -> Phase 4 multi-LLM routing (2-3 months)

**GO criteria assessment:**
- PTY intercept can reliably detect tool calls: NO (corrected — use MCP instead, which is reliable)
- Terminal project supports task chrome: YES (WezTerm Lua API, zero TermLink changes)
- Multi-LLM routing feasible: YES (2-3 months, extending existing orchestrator)

**Research artifacts:** `docs/reports/T-1061-termlink-governance-substrate.md`, `docs/reports/T-1061-termlink-review-feedback.md`

## Decisions

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: TermLink's governance substrate thesis is validated — but the mechanism is MCP + hub orchestrator + data plane, NOT PTY byte stream parsing. The TermLink project itself reviewed the document (19KB, code-path-specific corrections) and confirmed: governance at the structured API layer is feasible and architecturally correct. PTY parsing is rejected as infeasible (deadlock risk, terminal emulator trap, coupled to output format).

Evidence:
- TermLink already has go...

**Date**: 2026-04-08T05:30:50Z
## Decision

**Decision**: GO

**Rationale**: Recommendation: GO

Rationale: TermLink's governance substrate thesis is validated — but the mechanism is MCP + hub orchestrator + data plane, NOT PTY byte stream parsing. The TermLink project itself reviewed the document (19KB, code-path-specific corrections) and confirmed: governance at the structured API layer is feasible and architecturally correct. PTY parsing is rejected as infeasible (deadlock risk, terminal emulator trap, coupled to output format).

Evidence:
- TermLink already has go...

**Date**: 2026-04-08T05:30:50Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-04-07T20:52:45Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-08T05:30:50Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Recommendation: GO

Rationale: TermLink's governance substrate thesis is validated — but the mechanism is MCP + hub orchestrator + data plane, NOT PTY byte stream parsing. The TermLink project itself reviewed the document (19KB, code-path-specific corrections) and confirmed: governance at the structured API layer is feasible and architecturally correct. PTY parsing is rejected as infeasible (deadlock risk, terminal emulator trap, coupled to output format).

Evidence:
- TermLink already has go...

### 2026-04-08T05:30:50Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO

### 2026-04-12T09:27:15Z — status-update [task-update-agent]
- **Change:** horizon: now → next

## Reviewer Verdict (v1.5)

- **Scan ID:** R-3307cc1d
- **Timestamp:** 2026-06-02T14:54:54Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
