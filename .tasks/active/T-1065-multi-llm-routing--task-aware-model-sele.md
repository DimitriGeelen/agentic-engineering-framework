---
id: T-1065
name: "Multi-LLM routing — task-aware model selection via TermLink dispatch"
description: >
  Phase 4 from T-1061: Task-aware model selection with dispatch system spawning per-model workers. Extends Phase 3 orchestrator routing. 2-3 months.

status: started-work
workflow_type: build
owner: human
horizon: now
tags: [termlink, multi-llm, routing]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:25Z
last_update: 2026-04-28T17:31:57Z
date_finished: null
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

### Human
- [ ] [REVIEW] Multi-LLM routing design — model selection strategy is sound and cost-effective
  **Steps:**
  1. Review the routing logic and model selection heuristics
  2. Verify fallback chain is sensible (e.g., opus -> sonnet -> haiku)
  3. Check that cost implications are considered (route cheap tasks to cheap models)
  **Expected:** Clean model routing with intelligent defaults
  **If not:** Note where the cost model is wrong or where routing decisions are opaque

## Verification

# Phase 4a worker artefact (model passthrough)
test -f /opt/termlink/docs/reports/T-906-model-param-dispatch.md
# Phase 4b worker artefact (route-cache + circuit-breaker — T-1590 closure)
test -f /opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md
# T-1590 work-completed (scope-split closure task moved to completed/)
test -f .tasks/completed/T-1590-multi-llm-routing-phase-4b--route-cache-.md

## Recommendation

**Recommendation:** GO

**Rationale:** Full Phase 4 scope now shipped. The 2 ACs originally split as "future" (route-cache model tracking, circuit-breaker fallback) closed via T-1590 Phase 4b on 2026-04-28. All 7 Agent ACs satisfied with evidence. Task awaits Human [REVIEW] of the integrated multi-LLM routing design (passthrough + tracking + fallback as one coherent system).

**Evidence:**
- Phase 4a (passthrough): `/opt/termlink/docs/reports/T-906-model-param-dispatch.md` — 3 tests pass (opus, sonnet, absent).
- Phase 4b (tracking + fallback): `/opt/termlink/docs/reports/T-907-multi-llm-routing-phase-4b.md` — `RouteCache::record_model_success/failure`, `RouteCache::best_model_for`, `ModelCircuitBreaker::resolve_model`, `DEFAULT_MODEL_FALLBACK` chain wired into `termlink_dispatch`. 5 new tests in termlink-mcp.
- Integrated test count: 480/0 (278 hub unit + 103 mcp unit + 99 mcp integration). `cargo test` exit 0.
- T-1590 closed scope split — `.tasks/completed/T-1590-multi-llm-routing-phase-4b--route-cache-.md`.
- Decisions block updated 2026-04-28 to record scope-split closure.

## Decisions

### 2026-04-08 — Model routing scope split
- **Chose:** Model passthrough first, routing intelligence later
- **Why:** Model passthrough is the foundation. Route cache model tracking and circuit breaker fallback are separate concerns that build on it.
- **Rejected:** Implementing full model routing in one task (timed out on first attempt, scope too large)

### 2026-04-28 — Scope-split closed
- **Chose:** Mark the 2 originally-deferred ACs as satisfied by T-1590 (Phase 4b)
- **Why:** T-1590 shipped exactly the deferred work — `record_model_*`, `best_model_for`, `ModelCircuitBreaker::resolve_model`, `DEFAULT_MODEL_FALLBACK` — all wired into `termlink_dispatch` with 5 new tests. The split was a sequencing decision, not a permanent boundary; bringing the ACs back together is the honest accounting now that both halves exist.
- **Rejected:** Leaving the 2 ACs unchecked indefinitely — would misrepresent the integrated system as still partial; reviewer would re-flag them on every Pass-A scan.

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

## Reviewer Verdict (v1.4)

- **Scan ID:** R-d18730d9
- **Timestamp:** 2026-04-28T18:13:48Z
- **Catalogue:** v1.3-seed
- **Overall:** PASS
- **Needs Human:** no
- **Findings:** none
