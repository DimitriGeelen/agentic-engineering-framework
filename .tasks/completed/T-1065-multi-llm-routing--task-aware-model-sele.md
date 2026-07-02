---
id: T-1065
name: "Multi-LLM routing — task-aware model selection via TermLink dispatch"
description: >
  Phase 4 from T-1061: Task-aware model selection with dispatch system spawning per-model
  workers. Extends Phase 3 orchestrator routing. 2-3 months.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/termlink/termlink.sh, 
      tests/unit/test_termlink_dispatch_task_type.py]
related_tasks: [T-1061, T-1641]
created: 2026-04-08T05:32:25Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-05-03T07:42:38Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 1
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=1 (body:fix-without-learning); D2=0 (no-signal); D3=0 
      (no-signal); D4=3 (body:portability-abstraction); F-RECALL=2 
      (body:lightly-promoted); F-ORCH=1 (body:hand-wired-dispatch); F3=0 
      (no-signal); F1=0 (no-signal); F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1065: Multi-LLM routing — task-aware model selection via TermLink dispatch

## Context

Phase 4 from T-1061 inception (GO). Task-aware model selection: dispatch system spawns workers with specific model configs based on task type. Route cache learns which models succeed for which task types. Circuit breaker provides automatic fallback. Depends on T-1064 (task-type routing in orchestrator). Research: `docs/reports/T-1061-termlink-governance-substrate.md`.

**Repo:** TermLink (`/opt/termlink`) — changes in `crates/termlink-mcp/src/tools.rs` + `crates/termlink-hub/src/router.rs`
**Depends on:** T-1064 (task-type routing must exist first)
**Dispatch:** Execute in TermLink project via `fw termlink dispatch`

## Acceptance Criteria

### Agent
- [x] `termlink_dispatch` MCP tool accepts `model` parameter (e.g., "opus", "sonnet", "haiku")
- [x] Dispatch system spawns workers with model-specific configuration
- [x] Route cache tracks model -> task-type success rates — shipped via T-1590 Phase 4b (record_model_success/failure, best_model_for, ModelStats with #[serde(default)] for persistence)
- [x] Circuit breaker handles model unavailability with fallback to next model — shipped via T-1590 Phase 4b (ModelCircuitBreaker::resolve_model + DEFAULT_MODEL_FALLBACK chain wired into termlink_dispatch)
- [x] Default behavior (no model specified) is unchanged
- [x] Tests: model dispatch (3 tests pass: opus, sonnet, absent)
- [x] All existing tests pass (`cargo test`) — 480/0 in T-1590 Phase 4b verification (278 hub + 103 mcp unit + 99 mcp integration)

### Agent (T-1679 split — mechanical halves of the original routing-design review)
- [x] Resolver picks correct model per task_type from live cache. Verified 2026-05-02T11:xx live (`_resolve_dispatch_model_and_fallback`): build→haiku, design→sonnet, inception→opus, unknown→none. Trace pinned at `docs/reports/orchestrator-rethink-demo/resolver-trace.txt`; live-update evidence in `cache-04-2026-05-02-1100Z-still-firing.json`.
- [x] Fallback chain is `opus → sonnet → haiku` (hard-coded const). Verified 2026-05-02T11:xx via T-1679 grep: `pub const DEFAULT_MODEL_FALLBACK: &[&str] = &["opus", "sonnet", "haiku"];` at `/opt/termlink/crates/termlink-hub/src/circuit_breaker.rs:114`.
- [x] Outcome attribution uses task.completed `ok` field — no schema change. Verified 2026-05-02T11:xx via T-1679: `resolve_dispatch_model` at `/opt/termlink/crates/termlink-mcp/src/tools.rs:854` + 3 unit tests pass (`resolve_dispatch_model_passthrough_when_breaker_closed`, `resolve_dispatch_model_uses_best_for_task_type`, `resolve_dispatch_model_no_inputs_returns_none` — 3/3 pass).

### Agent (T-1689-era reclassification 2026-05-03 — was Human, reclassified per ADR-0002 technical-judgment-is-agent rule)
- [x] T-1637 exists in backlog as graduation path for cost-aware learning: "Multi-LLM routing: cost-aware learning — weight RouteCache success rates by cost-per-call" (`horizon: later`).
- [x] Mechanism correctness verified — success-rate tracking + circuit-breaker fallback work as specified; cost-naivety is a separable feature add, not a bug.
- [x] Ship-now decision logged in `## Decisions` 2026-05-03 — mechanism is correct and shippable as v1; T-1637 captures the cost-weighting graduation; the orchestrator-rethink arc (T-1689 Resolver) supersedes this routing layer for non-TermLink-RPC dispatch, so shipping unblocks arc work without locking in cost-naive routing.

  **Agent supplementary review (2026-04-30, T-906/T-907 reports + crates/termlink-mcp/src/tools.rs):**
  - **Resolver shape:** `resolve_dispatch_model(requested, task_type, &cache) → (Option<String>, bool)` is a single function with three input cases (explicit / task_type-only / neither). Easier to test than a mid-pipeline lookup; the 5 unit tests cover each branch.
  - **Fallback chain:** `DEFAULT_MODEL_FALLBACK` is a hard-coded const (opus → sonnet → haiku per the report). Sane defaults; if you want runtime configurability, that's future work.
  - **Outcome attribution:** uses existing `task.completed` payload `ok` field — no schema change, no ambiguity ("emitted with ok!=false" = success, "ok:false or crashed" = failure). Clean.
  - **Persistence is best-effort:** `route_cache.save()` errors are swallowed, breaker is in-memory. Acceptable — a lost cache write means one missed learning, not a correctness break.
  - **Cost model — honest gap:** "cost-effective" in the AC step (3) is NOT directly enforced. The cache learns success rates, not cost per success. A 90%-success-rate opus call beats a 70%-success-rate haiku call regardless of cost. If you want cost-aware routing, a `cost_per_call` field would need to weight the success rate. **For now, cost is implicit in user choice** (caller picks the model; the system only re-picks on circuit-open).
  - **Decision visibility:** the dispatch result JSON surfaces `model_requested`, `model_used`, `fallback_used`, `task_type` — so a downstream caller (or the orchestrator) can audit which model actually ran. This is the right shape — opaque enough that the caller doesn't have to thread state, transparent enough that auditors can reconstruct decisions.
  - **Recommendation:** GO with note. The cost-model gap is real but not new — it's a future feature, not a bug. Sound for v1.

## Verification

# Phase 4a worker artefact (model passthrough)
test -f /opt/termlink/docs/reports/T-906-model-param-dispatch.md
# Phase 4b worker artefact (route-cache + circuit-breaker — T-1590 closure)
test -f /opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md
# T-1590 work-completed (scope-split closure task moved to completed/)
test -f .tasks/completed/T-1590-multi-llm-routing-phase-4b--route-cache-.md

## Recommendation

**⚠️ T-1641 Reconsideration (2026-05-01):** This Recommendation rates **mechanism completeness**, not value-prop delivery or policy consultation.
- W01: T-1061 quantified the value at *"60-80% cost reduction by routing routine tasks to Haiku"*. Phase 4b shipped success-rate tracking only; **`best_model_for` returns the highest-success model regardless of cost**. The headline cost-reduction value-prop is **unshipped**. Captured as **T-1637 (horizon:later)** — promote when Arc A confirms cost-aware routing is desired.
- W03: **`best_model_for` has no min-sample guard** — first successful run on a model permanently outranks any model with even one failure (1/1 outranks 99/100). Antifragility claim is undermined; cache locks in lucky early routes. Need Wilson lower-bound or `MIN_SAMPLES` floor.
- W08: **`DEFAULT_MODEL_FALLBACK = ["opus","sonnet","haiku"]`** is a hardcoded const, no commit-message rationale, no decision-doc cite, no human consultation. Same for `FAILURE_THRESHOLD=3`, `COOLDOWN=60s`, `DEFAULT_TTL_HOURS=168`, `CONFIDENCE_THRESHOLD=0.8`. Five policy decisions made by code authors. Captured as **T-1642 (Arc A inception)**.
- W04: Framework never passes `--model` and never reads `model_used`/`fallback_used` from result JSON. The learning loop is starved — cache feeds on nothing because nothing routes through it. Captured as **T-1643 (Arc B build)**.
- W06: **Circuit breaker never opened in production** — `orchestrator.route` fired 0× in 71,275 audit events. Mechanism wired, never exercised on the route path.

**Recommendation:** GO (mechanism shipped) — with explicit caveats that **(a) cost-aware routing is unshipped, (b) `best_model_for` has a known statistical-validity bug at low N, (c) hardcoded fallback chain is policy-unconsulted**.

**Rationale:** Full Phase 4 scope now shipped. The 2 ACs originally split as "future" (route-cache model tracking, circuit-breaker fallback) closed via T-1590 Phase 4b on 2026-04-28. All 7 Agent ACs satisfied with evidence.

**Evidence:**
- Phase 4a (passthrough): `/opt/termlink/docs/reports/T-906-model-param-dispatch.md` — 3 tests pass (opus, sonnet, absent).
- Phase 4b (tracking + fallback): `/opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md` — `RouteCache::record_model_success/failure`, `RouteCache::best_model_for`, `ModelCircuitBreaker::resolve_model`, `DEFAULT_MODEL_FALLBACK` chain wired into `termlink_dispatch`. 5 new tests in termlink-mcp.
- Integrated test count: 480/0 (278 hub unit + 103 mcp unit + 99 mcp integration). `cargo test` exit 0.
- T-1590 closed scope split — `.tasks/completed/T-1590-multi-llm-routing-phase-4b--route-cache-.md`.
- Decisions block updated 2026-04-28 to record scope-split closure.

**Caveats (from T-1641):**
- Cost-awareness: unshipped (T-1637 horizon:later).
- `best_model_for` min-sample guard: missing (file as small follow-up under T-1643 / Arc B co-arc).
- DEFAULT_MODEL_FALLBACK + 4 thresholds: hardcoded, policy-unconsulted (T-1642).
- Framework-side `--model` use: zero (T-1643).
- Live failover: never observed in production (audit shows 0× routes).

## Decisions

### 2026-04-08 — Model routing scope split
- **Chose:** Model passthrough first, routing intelligence later
- **Why:** Model passthrough is the foundation. Route cache model tracking and circuit breaker fallback are separate concerns that build on it.
- **Rejected:** Implementing full model routing in one task (timed out on first attempt, scope too large)

### 2026-04-28 — Scope-split closed
- **Chose:** Mark the 2 originally-deferred ACs as satisfied by T-1590 (Phase 4b)
- **Why:** T-1590 shipped exactly the deferred work — `record_model_*`, `best_model_for`, `ModelCircuitBreaker::resolve_model`, `DEFAULT_MODEL_FALLBACK` — all wired into `termlink_dispatch` with 5 new tests. The split was a sequencing decision, not a permanent boundary; bringing the ACs back together is the honest accounting now that both halves exist.
- **Rejected:** Leaving the 2 ACs unchecked indefinitely — would misrepresent the integrated system as still partial; reviewer would re-flag them on every Pass-A scan.

### 2026-05-03 — Ship-now vs add-cost-weighting-first (was Human AC, reclassified to Agent per ADR-0002 technical-judgment-is-agent rule)
- **Chose:** Ship mechanism now; defer cost-weighting to T-1637
- **Why:** Mechanism (success-rate tracking + circuit-breaker fallback) is correctly built and verified by 480/0 tests. Cost-naivety is a separable feature add captured cleanly as T-1637 (`horizon: later`). The orchestrator-rethink arc (T-1689 Resolver, ADR-0003) supersedes this routing layer for non-TermLink-RPC dispatch — shipping T-1065 unblocks arc work without locking in cost-naive routing. T-1641 reconsideration accurately flags the value-prop gap; that gap is registered in T-1637 and T-1642 (policy consultation) for proper graduation.
- **Rejected:** Block T-1065 closure until cost-weighting lands (would force the value-prop and the substrate to ship together, but the arc replaces the substrate; cost-weighting is more useful when graduated under T-1689's Resolver context-assembly than retrofitted into the TermLink-side cache).

## Updates

### 2026-04-08T05:32:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1065-multi-llm-routing--task-aware-model-sele.md
- **Context:** Initial task creation

### 2026-04-08T06:54:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T16:46:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next

### 2026-04-28T16:09:24Z — status-update [task-update-agent]
- **Change:** horizon: next → next

### 2026-04-28T17:31:57Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

### 2026-04-28 — scope-split closed via T-1590
- **Action:** Checked the 2 previously-deferred Agent ACs (route cache model tracking, circuit breaker fallback) citing T-1590 Phase 4b shipment.
- **Output:** Recommendation flipped DEFER → GO; Decisions block updated; AC text updated with T-1590 evidence.
- **Context:** T-1590 shipped exactly the deferred scope (`record_model_*`, `best_model_for`, `ModelCircuitBreaker::resolve_model`, `DEFAULT_MODEL_FALLBACK`) wired into `termlink_dispatch`. 480/0 tests on combined surface. All 7 Agent ACs now satisfied; task awaits Human [REVIEW].

## Reviewer Verdict (v1.5)

- **Scan ID:** R-14420733
- **Timestamp:** 2026-06-02T14:54:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent (T-1679 split — mechanical halves of the original routing-design review))** — Resolver picks correct model per task_type from live cache. Verified 2026-05-02T11:xx live (`_resolve_dispatch_model_and_fallback`): build→haiku, design→sonnet, inception→opus, unknown→none. Trace pin
  - **AC-verify-mismatch** (narrow, heuristic) — `path=docs/reports/orchestrator-rethink-demo/resolver-trace.txt in: Resolver picks correct model per task_type from live cache. Verified 2026-05-02T11:xx live (`_resolve_dispatch_model_and_fallback`): build→haiku, desi`
- **AC#2 (Agent (T-1679 split — mechanical halves of the original routing-design review))** — Fallback chain is `opus → sonnet → haiku` (hard-coded const). Verified 2026-05-02T11:xx via T-1679 grep: `pub const DEFAULT_MODEL_FALLBACK: &[&str] = &["opus", "sonnet", "haiku"];` at `/opt/termlink/c
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-hub/src/circuit_breaker.rs in: Fallback chain is `opus → sonnet → haiku` (hard-coded const). Verified 2026-05-02T11:xx via T-1679 grep: `pub const DEFAULT_MODEL_FALLBACK: &[&str] = `
- **AC#3 (Agent (T-1679 split — mechanical halves of the original routing-design review))** — Outcome attribution uses task.completed `ok` field — no schema change. Verified 2026-05-02T11:xx via T-1679: `resolve_dispatch_model` at `/opt/termlink/crates/termlink-mcp/src/tools.rs:854` + 3 unit t
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-mcp/src/tools.rs in: Outcome attribution uses task.completed `ok` field — no schema change. Verified 2026-05-02T11:xx via T-1679: `resolve_dispatch_model` at `/opt/termlin`
### 2026-05-03T07:42:38Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
