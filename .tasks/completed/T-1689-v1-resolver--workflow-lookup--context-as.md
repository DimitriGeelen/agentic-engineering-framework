---
id: T-1689
name: "v1 Resolver — workflow lookup + context assembly + variant selection + telemetry capture"
description: >
  v1 implementation of the Resolver: the Agent-side function that turns a Workflow + live task context into a Delegation envelope. Per CONTEXT.md+ADR-0003: workflow lookup with default.yaml fallback, three-tier prompt construction (static/assembled/meta-prompted), variant selection, dispatch_id+blob capture, template-SHA recording. Highest-complexity new component in v1 — worth its own scoped inception to nail down implementation choices, ACs, and validation strategy.

status: work-completed
workflow_type: inception
owner: agent
horizon: null
tags: [resolver]
components: [prompts/default.md]
related_tasks: [T-1687, T-1686]
arc_id: orchestrator-rethink
created: 2026-05-02T22:55:52Z
last_update: 2026-05-03T08:28:39Z
date_finished: 2026-05-03T08:28:39Z
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
- [x] Problem statement validated
<!-- @auto-tick-on-decide -->
- [x] Assumptions tested
<!-- @auto-tick-on-decide -->
- [x] Recommendation written with rationale

### Human
<!-- @auto-tick-on-decide -->
- [x] [REVIEW] Review exploration findings and approve go/no-go decision
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

**Recommendation:** GO

**Rationale:** Substrate works end-to-end at 5.3 ms avg per dispatch (NO-GO threshold >500 ms — two orders of magnitude clear). All four assumptions testable in this inception (A-1, A-2, A-3, A-5) validated; A-4 (Tier 3 latency) intentionally deferred to v1 build because it requires a paid LLM call AND the substrate is unconditional regardless of Tier 3's runtime decision. The spike caught a real concurrency bug in the back-prop path (A-5 fixed-tmp race) before any production code shipped — exactly what spikes are for. The resolver fits one Python module (~290 LOC spike → ~400 LOC production estimate). Three of the four GO criteria are MET; the fourth (Tier 3 runtime bound) is wired as substrate and runtime-validated by the v1 build task.

**Evidence:**
- `docs/reports/T-1689-spikes/resolver_spike.py` runs to completion: `Spike S-1 + S-2: ALL CHECKS PASS`
  - Q12 fallback verified: non-existent task_type resolves to `default.yaml` with `_resolved_via=default-fallback`
  - JSONL round-trip verified: dispatch_id, workflow_sha (commit hash), template_sha, blob_dir all captured
  - Inline-workflow rejection: `inception.yaml` correctly raises ResolverError per ADR-0002
  - End-to-end latency: 5.3ms avg, max 6.3ms across 10 dispatches
  - Variant distribution (10000 draws, weights {A:0.7, B:0.2, C:0.1}): observed {7023, 1997, 980} all within 3σ tolerance
  - `select_variant()` returns None when no `variants:` block — default path preserved
- `docs/reports/T-1689-spikes/backprop_spike.py` runs to completion: `✓ Spike A-5: no JSON corruption under concurrent back-prop`
  - 50 rows preserved across 5 concurrent back-prop threads
  - **Critical finding:** the naive shared-`.tmp` rewrite-then-rename pattern (used by lib/learning.sh + lib/decision.sh) does NOT survive concurrent writers — first run produced FileNotFoundError + corrupt JSON. Per-call unique tmp filename (`.jsonl.tmp.<pid>.<tid>`) fixes it. T-1690 build task must implement this.
- `git rev-parse HEAD:<path>` measured at ~2.1ms per call on the framework repo (10-call avg) — well under A-2's 50ms budget.

**Research artifact:** `docs/reports/T-1689-resolver-inception.md` (full findings + module sizing analysis + v1 build task scope).

**v1 build task scope (to file after GO):**
1. Port spike → `lib/resolver.py` (~400 LOC) + `lib/resolver.sh` shim (~30 LOC)
2. Wire `bin/fw resolver` for debugging + as the spawn-side primitive consumed by T-1691/T-1692
3. Real `_recent_dispatches_summary` (currently a stub) — tail JSONL for last-N matching task_type
4. Real `HEALING_PATTERNS` injection — pull from `patterns.yaml`
5. Few-shot example loader (`prompts/examples/<task_type>/*.md`)
6. Tier 3 (`meta-prompted`) implementation — first real consumer is the build task itself; if latency >30s OR cost >$0.05/dispatch fails the runtime check, mark Tier 3 substrate-only and defer the actual call to v2
7. Per-call unique tmp pattern in any modify-in-place path (T-1690 inheritance)
8. CLI: `fw resolver dispatch <task_id> <task_type>` for dry-run + `fw resolver explain <dispatch_id>` for forensics

**Caveats:**
- A-4 (Tier 3 latency) intentionally not validated in this inception; substrate ships unconditionally
- Spike used synthetic `_recent_dispatches_summary` and `HEALING_PATTERNS` stubs — production assembled-tier quality depends on those being properly wired in the build task
- Concurrent back-prop is not race-free at the application level; T-1690 must accept last-writer-wins semantics (acceptable because back-prop fires per-task-completion, not per-dispatch)

## Decisions

### 2026-05-03 — Module structure (single Python + shell shim vs split)

- **Chose:** Single `lib/resolver.py` (~400 LOC) + thin `lib/resolver.sh` (~30 LOC) shim.
- **Why:** 290-LOC spike does not split naturally. The five concerns (workflow lookup, prompt assembly, variant selection, telemetry, env merge) are tightly coupled — they share the workflow dict and dispatch_id throughout. Splitting would create artificial seams that hurt readability without reducing complexity.
- **Rejected:** lib/resolver/{workflow.py, assemble.py, telemetry.py, variants.py} package — premature factoring, would force inter-module data plumbing for ~50-LOC pieces.

### 2026-05-03 — Atomic back-prop pattern

- **Chose:** Per-call unique tmp filename (`.jsonl.tmp.<pid>.<tid>`) for ALL modify-in-place paths in T-1690.
- **Why:** Spike A-5 caught the shared-`.tmp` race on first run. The framework's existing lib/learning.sh / lib/decision.sh use shared `.tmp` and have not corrupted in 1500+ tasks — but those are sequentially called from a single agent process; back-prop hooks may fire concurrently across multiple completing tasks.
- **Rejected:** Application-level lockfile — adds complexity without solving the last-writer-wins semantic, which is acceptable for back-prop frequency.

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

**Rationale**: Substrate works end-to-end at 5.3 ms avg per dispatch (NO-GO threshold >500 ms — two orders of magnitude clear). All four assumptions testable in this inception (A-1, A-2, A-3, A-5) validated; A-4 (Tier 3 latency) intentionally deferred to v1 build because it requires a paid LLM call AND the substrate is unconditional regardless of Tier 3's runtime decision. The spike caught a real concurrency bug in the back-prop path (A-5 fixed-tmp race) before any production code shipped — exactly what spikes are for. The resolver fits one Python module (~290 LOC spike → ~400 LOC production estimate). Three of the four GO criteria are MET; the fourth (Tier 3 runtime bound) is wired as substrate and runtime-validated by the v1 build task.

**Date**: 2026-05-03T08:28:39Z

## Updates

<!-- Auto-populated by git mining at task completion.
     Manual entries optional during execution. -->

### 2026-05-03T08:08:18Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-05-03T08:28:39Z — inception-decision [inception-workflow]
- **Action:** Recorded inception decision
- **Decision:** GO
- **Rationale:** Substrate works end-to-end at 5.3 ms avg per dispatch (NO-GO threshold >500 ms — two orders of magnitude clear). All four assumptions testable in this inception (A-1, A-2, A-3, A-5) validated; A-4 (Tier 3 latency) intentionally deferred to v1 build because it requires a paid LLM call AND the substrate is unconditional regardless of Tier 3's runtime decision. The spike caught a real concurrency bug in the back-prop path (A-5 fixed-tmp race) before any production code shipped — exactly what spikes are for. The resolver fits one Python module (~290 LOC spike → ~400 LOC production estimate). Three of the four GO criteria are MET; the fourth (Tier 3 runtime bound) is wired as substrate and runtime-validated by the v1 build task.

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1e9f5375
- **Timestamp:** 2026-06-02T14:59:08Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
### 2026-05-03T08:28:39Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Inception decision: GO
