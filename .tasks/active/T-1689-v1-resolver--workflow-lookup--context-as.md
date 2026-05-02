---
id: T-1689
name: "v1 Resolver — workflow lookup + context assembly + variant selection + telemetry capture"
description: >
  v1 implementation of the Resolver: the Agent-side function that turns a Workflow + live task context into a Delegation envelope. Per CONTEXT.md+ADR-0003: workflow lookup with default.yaml fallback, three-tier prompt construction (static/assembled/meta-prompted), variant selection, dispatch_id+blob capture, template-SHA recording. Highest-complexity new component in v1 — worth its own scoped inception to nail down implementation choices, ACs, and validation strategy.

status: captured
workflow_type: inception
owner: agent
horizon: now
tags: [arc:orchestrator-rethink, resolver]
components: []
related_tasks: [T-1687, T-1686]
created: 2026-05-02T22:55:52Z
last_update: 2026-05-02T22:55:52Z
date_finished: null
---

# T-1689: v1 Resolver — workflow lookup + context assembly + variant selection + telemetry capture

## Problem Statement

The Resolver is the load-bearing new component for v1 dispatch. CONTEXT.md + ADR-0003 specify WHAT it does (workflow lookup with default.yaml fallback per Q12; three-tier prompt construction static/assembled/meta-prompted; variant selection; dispatch_id + blob capture; template-SHA recording; outcome enrichment hook integration with T-1690). This inception scopes HOW to build it: module layout, error handling, latency characteristics, and the end-to-end validation strategy that proves the substrate works before T-1690/T-1691/T-1692/T-1693/T-1694/T-1695 start consuming it.

## Assumptions

- A-1: A single Python module (`lib/resolver.py`) + small shell shim is the right structural fit — matches existing patterns (`lib/bus.py`, `lib/audit.py`).
- A-2: `git rev-parse HEAD:<path>` at dispatch time has acceptable latency (<50ms) for both workflow files and templates.
- A-3: `.context/dispatch-blobs/` is structurally separate from `.context/bus/blobs/` — no path collision risk.
- A-4: Tier 3 (meta-prompted) latency (5–30s haiku → sonnet meta-step) is acceptable for workflows that opt in; not a v1 blocker.
- A-5: `dispatches.jsonl` modify-in-place for back-prop (T-1690) is achievable atomically (rewrite-then-rename) — worth verifying before T-1690 starts.

## Exploration Plan

- Spike S-1 (1 session): single-tier `assembled` resolver end-to-end — workflow lookup, $VAR substitution from frontmatter + dispatches.jsonl, one dispatch via TermLink, JSONL row + blob written, route_cache updated. Verify telemetry round-trip.
- Spike S-2 (½ session): Tier 3 meta-prompt — measure haiku-meta latency + cost for a representative build prompt, validate meta-prompt blob captured.
- Spike S-3 (½ session): variant selection — wire `variants:` field, dispatch 10 times, verify weighted distribution + `variant_id` recorded.

## Technical Constraints

- Resolver runs in the parent Agent process — must not block the Agent's interactive loop noticeably.
- Workers (TermLink, pi) are spawned with `--bare`; resolver must construct a complete envelope without relying on inherited context.
- ANTHROPIC_BASE_URL env redirect (Q11) is a per-workflow `env:` map; resolver must merge into the spawned worker's environment without leaking to the parent.

## Scope Fence

- IN: workflow file lookup + default.yaml fallback (Q12); three-tier prompt construction (static/assembled/meta-prompted); variant selection; dispatch_id + blob capture; template SHA recording; integration points for T-1690 (outcome evaluator hook), T-1691 (env-redirect for ollama), T-1692 (worker_kind=pi handoff); ANTHROPIC_BASE_URL env merge.
- OUT: outcome evaluator implementation (→ T-1690); workflow file linter (→ T-1694); pi RPC wrapper (→ T-1692); ollama proxy install/config (→ T-1691); v2 self-improvement learner; cross-machine dispatch (out of scope for v1).

## Acceptance Criteria

### Agent
<!-- @auto-tick-on-decide -->
- [ ] Problem statement validated
<!-- @auto-tick-on-decide -->
- [ ] Assumptions tested
<!-- @auto-tick-on-decide -->
- [ ] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [ ] [REVIEW] Review exploration findings and approve go/no-go decision
  **Steps:**
  1. Run: `fw task review T-XXX` (opens Watchtower with recommendation, assumptions, research artifacts)
  2. Review the Agent Recommendation section and go/no-go criteria evaluation
  3. Record decision via the Watchtower form or the command shown alongside the QR code
  **Expected:** Decision recorded, task completed
  **If not:** Ask agent for clarification on specific findings

## Go/No-Go Criteria

**GO if:**
- S-1 spike works end-to-end for Tiers 1+2 with full telemetry round-trip (JSONL row + blob + route_cache update + dispatch_id traceable)
- S-2 spike confirms Tier 3 meta-prompt latency is bounded (<30s) and cost is acceptable (<$0.05/dispatch on haiku)
- S-3 spike confirms variant slot wiring works without breaking the default-no-variants path
- Resolver fits in a single Python module (signal that scope is right-sized)

**NO-GO if:**
- Telemetry capture creates dispatch latency overhead >500ms (substrate is too heavy)
- JSONL modify-in-place is unsafe under concurrent dispatches (forces T-1690 to redesign storage)
- Tier 3 latency makes meta-prompted dispatch unusable in practice (defer Tier 3 to v2)
- Resolver requires more than one Python module + shim (signal scope is too big — split before building)

## Verification

# Shell commands that MUST pass before work-completed. One per line.
# Lines starting with # are comments (skipped). Empty lines ignored.
# For inception tasks, verification is often not needed (decisions, not code).
#
# Toolchain hint (L-291): if a GO decision will mean editing *.vbproj/*.csproj/*.xaml,
# *.go, Cargo.toml, tsconfig.json, or pom.xml in the build task, plan to add the
# matching build command (dotnet build / go build / cargo check / tsc --noEmit /
# mvn compile) to that build task's ## Verification — P-011 only runs what you write.

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
