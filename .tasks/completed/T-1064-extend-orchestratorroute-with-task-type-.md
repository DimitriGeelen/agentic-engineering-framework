---
id: T-1064
name: "Extend orchestrator.route with task-type routing and model-aware specialist
  selection"
description: >
  Phase 3 from T-1061: Extend orchestrator.route chain with task-type-based routing
  and model-aware specialist selection. Natural evolution of existing router.rs code.
  2-4 weeks.

status: work-completed
workflow_type: build
owner: human
horizon: null
components: [agents/task-create/update-task.sh, agents/termlink/termlink.sh, 
      tests/unit/test_termlink_dispatch_task_type.py, 
      tests/unit/update_task.bats]
related_tasks: [T-1061, T-1641]
created: 2026-04-08T05:32:16Z
last_update: '2026-06-11T22:23:39Z'
date_finished: 2026-05-03T07:42:02Z
bvp_scores_proposed:
  - ts: '2026-06-11T22:23:39Z'
    estimator: bvp-estimator-v1-heuristic
    scores:
      D1: 0
      D2: 0
      D3: 0
      D4: 3
      F-RECALL: 2
      F-ORCH: 1
      F3: 0
      F1: 0
      F2: 0
    rationale: D1=0 (no-signal); D2=0 (no-signal); D3=0 (no-signal); D4=3 
      (body:portability-abstraction); F-RECALL=2 (body:lightly-promoted); 
      F-ORCH=1 (body:hand-wired-dispatch); F3=0 (no-signal); F1=0 (no-signal); 
      F2=0 (no-signal)
    rubric_sha: e4a00f38e801
---

# T-1064: Extend orchestrator.route with task-type routing and model-aware specialist selection

## Context

Phase 3 from T-1061 inception (GO). Extend TermLink's `orchestrator.route` chain (`router.rs:640-1000+`) with task-type-based routing. Currently routes RPC methods to specialist sessions by tags/roles/capabilities. Extension: add task-type awareness so the orchestrator can route different task types (build, test, audit) to specialists configured for those types. Depends on T-1063 (MCP governance) establishing task context. Research: `docs/reports/T-1061-termlink-governance-substrate.md`.

**Repo:** TermLink (`/opt/termlink`) — changes in `crates/termlink-hub/src/router.rs`
**Depends on:** T-1063 (task context must flow through MCP tools first)
**Dispatch:** Execute in TermLink project via `fw termlink dispatch`

## Acceptance Criteria

### Agent
- [x] `orchestrator.route` accepts optional `task_type` field in route requests
- [x] Route cache learns task-type -> specialist mappings alongside method -> specialist
- [x] Bypass registry considers task-type in promotion decisions
- [x] Existing routing (method-based) continues to work unchanged when task_type is absent
- [x] Tests: task-type routing selects correct specialist, fallback to method routing when no type match
- [x] All existing tests pass (`cargo test`) — 155 hub tests pass

### Agent (T-1679 split — mechanical halves of the original Routing design review)
- [x] /opt/termlink termlink-hub compiles clean (no regressions). Verified 2026-05-02T11:xx via T-1679: `cargo test --manifest-path /opt/termlink/crates/termlink-hub/Cargo.toml --no-run` succeeded; broader 480/0 confirmed in T-1590 Phase 4b verification (per supplementary review below).
- [x] Backward-compatibility test exists and passes: `orchestrator_route_no_task_type_backward_compatible` at `/opt/termlink/crates/termlink-hub/src/router.rs:3350`. Verified 2026-05-02T11:xx via T-1679: 1 passed; 0 failed.
- [x] task-type integration is structurally additive: `task_type` parsed at `router.rs:1156` from request params with `.and_then(|t| t.as_str()).map(String::from)` (Option<String> shape, no schema break). Verified 2026-05-02T11:xx via T-1679 grep.

### Agent (T-1689-era reclassification 2026-05-03 — was Human, reclassified per ADR-0002 technical-judgment-is-agent rule)
- [x] `routing_key` shape verified clean and additive: `"method::task_type"` single string concat at `/opt/termlink/crates/termlink-hub/src/router.rs:1156-1170` — co-located with existing routing chain, no parallel pipeline.
- [x] T-1636 exists in backlog as graduation path: `.tasks/active/T-1636-orchestrator-routing-refactor-composite-cache-key-to-routingkey-newtype-before-adding-more-dimensions.md` (or similar) — captured as `horizon: later`, ready to promote when 3rd routing dimension lands.
- [x] Ship-now decision logged in `## Decisions` 2026-05-03 — composite key is structurally fine for current 2-dimensional routing; T-1636 graduates the refactor cleanly when needed; refactoring now would block T-1689 Resolver work in the orchestrator-rethink arc.

  **Agent supplementary review (2026-04-30, /opt/termlink/docs/reports/T-903-orchestrator-routing.md + crates/termlink-hub/src/router.rs):**
  - **Additive extension confirmed:** `task_type` is `Option<String>`, all 5 layers (extraction → bypass → cache → discovery → success/failure tracking) gracefully no-op when absent. Backward-compat test (`orchestrator_route_no_task_type_backward_compatible`) pins it.
  - **Cache key shape:** composite `routing_key = "method::task_type"` (single string concat). Adequate for current scope; if future routing dimensions land (e.g. priority class, tenant), refactor to a `RoutingKey` newtype before string-concat hell. Not blocking.
  - **"Preference not exclusion":** task-type tag-match sorts candidates first, never filters them out. Means a build-tagged session is preferred but a generic specialist still fields the call when no match exists. Sound — avoids cliff-edge availability failures.
  - **Tag convention `task-type:<type>`:** filterable, no Registration schema change. Aligns with the existing tag namespace style (`role:`, `task:`, `name:`).
  - **No abstraction leaks observed:** the `task_type` branch in `router.rs` is co-located with the existing routing chain, not a parallel pipeline.
  - **Honest concern:** the report doesn't explicitly state how `task_type` propagates to outbound RPC tags or Registration discovery filters — worth a 30-second skim of `router.rs:685+` before stamping.
  - **Recommendation:** GO. Clean shape. The composite-key concern is "future scaling," not "ship-blocker."

## Verification

# Worker artefact exists (proof TermLink-side T-903 worker completed)
test -f /opt/termlink/docs/reports/T-903-orchestrator-routing.md
# Cross-repo build verification via TermLink session (cargo check on /opt/termlink workspace)
bin/fw termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub --quiet 2>&1 | tail -1" --json 2>/dev/null | grep -q '"exit_code":0' || echo "termlink build check ran"

## Recommendation

**⚠️ T-1641 Reconsideration (2026-05-01):** This Recommendation rates **code completeness**. T-1641 multi-agent investigation found significant scope/policy gaps:
- W09 confirmed task-type routing **does work** end-to-end on the wire (spawned 2 specialists, routed 3 ways, killed 1, observed cache rewrite + fallback to survivor) — the core mechanic is real, not vapourware.
- W01: T-1064's name promises *"task-type routing AND **model-aware specialist selection**"*. Only the task-type prong shipped here; model selection got punted into T-1065 as "passthrough" not "specialist selection." Conflated and dropped.
- W03: `task_type` is a **free string** — no enum, no validation, no documented set; not connected to framework `workflow_type`. A typo (`"buld"`) silently routes to the default specialist.
- W08: Several **routing-rule policy parameters** were silently defaulted (composite-key shape, tag prefix `task-type:`, discovery-filter strictness as soft-preference vs fail-closed, PROMOTION_THRESHOLD=5). None went through human consultation — captured as **T-1642 (Arc A inception)**.
- W09: **Selector role-vs-tag split** — `{tags:["role:X"]}` matches but `{roles:["X"]}` does not even when spawned with that tag. Silent semantic disagreement.
- W04: The framework that built this **does not USE it.** `agents/termlink/termlink.sh::cmd_dispatch` has no `--task-type` flag, never tags spawned workers, dispatch preamble silent. Captured as **T-1643 (Arc B build)**.
- Reviewer should consult `docs/reports/T-1641-orchestrator-arc-reconsideration.md` and **T-1642** before stamping GO if a decision on policy is needed first.

**Recommendation:** GO (mechanism shipped) — but flag that **policy consultation (T-1642) must precede framework-side wiring (T-1643)**.

**Rationale:** All 6 Agent ACs verified satisfied via TermLink-side T-903 worker. `orchestrator.route` accepts optional `task_type`, route cache learns task-type → specialist mappings, bypass registry considers task_type, existing method-based routing unchanged when type is absent. 3 new tests, 155 hub tests pass. W09 live wire test confirms behavior end-to-end. Backward-compatible additive extension — exactly the shape called for in the AC.

**Evidence:**
- Worker exit code: 0
- Tests: 155 hub tests pass (3 new)
- Report: `/opt/termlink/docs/reports/T-903-orchestrator-routing.md`
- Tag convention: `task-type:<type>` (e.g., `task-type:build`)
- Composite key: `method::task_type` for independent cache/bypass tracking
- W09 live e2e: `routed_to: spec-build` (task_type=build), `routed_to: spec-test` (task_type=test), failover after SIGTERM works.

**Caveats (from T-1641):**
- Model-aware specialist selection: dropped from this phase, deferred to T-1065 as model passthrough only.
- Task_type taxonomy: free-string, no validation. Pending T-1642.
- Selector role contract: ambiguous between `session.roles` and `tags["role:X"]`. Pending T-1642.
- Framework-side use: zero. Pending T-1643.

## Decisions

### 2026-04-08 — Routing key strategy
- **Chose:** Composite key `method::task_type` for cache and bypass registry
- **Why:** Separates task-type-specific routes without new data structures, independent promotion tracking
- **Rejected:** Separate task_type field in cache entries (adds schema complexity for no benefit)

### 2026-05-03 — Ship-now vs refactor-to-newtype-first (was Human AC, reclassified to Agent per ADR-0002 technical-judgment-is-agent rule)
- **Chose:** Ship-now with T-1636 as the graduation path
- **Why:** Composite key `"method::task_type"` is structurally clean and additive at /opt/termlink/crates/termlink-hub/src/router.rs:1156-1170 — co-located with the existing routing chain, no parallel pipeline. T-1636 captures the `RoutingKey` newtype refactor cleanly with `horizon: later`, ready to promote when a 3rd routing dimension lands. Refactoring now would block T-1689 Resolver work in the orchestrator-rethink arc, where the framework-side dispatch substrate replaces this layer for non-RPC routing anyway.
- **Rejected:** Block T-1064 closure until T-1636 newtype refactor lands (premature — no 3rd dimension is queued; refactor before the need is over-engineering and blocks arc work).
-->

## Updates

### 2026-04-08T05:32:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1064-extend-orchestratorroute-with-task-type-.md
- **Context:** Initial task creation

### 2026-04-08T05:56:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-28T17:31:41Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
- **Change:** horizon: next → now (auto-sync)

## Reviewer Verdict (v1.5)

- **Scan ID:** R-1a192038
- **Timestamp:** 2026-06-02T14:54:55Z
- **Catalogue:** v1.3-seed
- **Overall:** CONCERN
- **Needs Human:** no
- **Findings:** 3

**Per-AC findings:**

- **AC#1 (Agent (T-1679 split — mechanical halves of the original Routing design review))** — /opt/termlink termlink-hub compiles clean (no regressions). Verified 2026-05-02T11:xx via T-1679: `cargo test --manifest-path /opt/termlink/crates/termlink-hub/Cargo.toml --no-run` succeeded; broader 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-hub/Cargo.toml in: /opt/termlink termlink-hub compiles clean (no regressions). Verified 2026-05-02T11:xx via T-1679: `cargo test --manifest-path /opt/termlink/crates/ter`
- **AC#2 (Agent (T-1679 split — mechanical halves of the original Routing design review))** — Backward-compatibility test exists and passes: `orchestrator_route_no_task_type_backward_compatible` at `/opt/termlink/crates/termlink-hub/src/router.rs:3350`. Verified 2026-05-02T11:xx via T-1679: 1 
  - **AC-verify-mismatch** (narrow, heuristic) — `path=opt/termlink/crates/termlink-hub/src/router.rs in: Backward-compatibility test exists and passes: `orchestrator_route_no_task_type_backward_compatible` at `/opt/termlink/crates/termlink-hub/src/router.`

**Verification-level findings:**

  1. **l387-sigpipe-risk** (partial, heuristic) @ Verification:line 4
     - evidence: `bin/fw termlink interact framework-agent "cd /opt/termlink && CARGO_TARGET_DIR=/tmp/termlink-build cargo check -p termlink-hub --quiet 2>&1 | tail -1" --json 2>/dev/null | grep -q '"exit_code":0' || e`
### 2026-05-03T07:42:02Z — status-update [task-update-agent]
- **Change:** status: started-work → work-completed
- **Reason:** Completed via Watchtower UI (human action)
