---
id: T-1064
name: "Extend orchestrator.route with task-type routing and model-aware specialist selection"
description: >
  Phase 3 from T-1061: Extend orchestrator.route chain with task-type-based routing and model-aware specialist selection. Natural evolution of existing router.rs code. 2-4 weeks.

status: captured
workflow_type: build
owner: human
horizon: next
tags: [termlink, routing, orchestrator]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:16Z
last_update: 2026-04-08T05:56:43Z
date_finished: null
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

### Human
- [ ] [REVIEW] Routing design review — task-type integration is clean and doesn't complicate the existing route chain
  **Steps:**
  1. Review the router.rs changes in the TermLink repo
  2. Check that task-type routing is additive (no breaking changes to existing flow)
  3. Verify the route cache schema evolution is backward-compatible
  **Expected:** Clean additive extension, no regressions
  **If not:** Note where the abstraction leaks or complicates the existing chain

## Verification

# Runs in /opt/termlink
# cd /opt/termlink && cargo test
# cd /opt/termlink && cargo build
# The completion gate runs each command — if any exits non-zero, completion is blocked.

## Recommendation

**Recommendation:** Agent ACs complete — ready for human design review
**Rationale:** TermLink worker (T-903 in /opt/termlink) added task_type to orchestrator.route. Preference-based routing (not exclusion), composite routing key, backward compatible. 3 new tests, 155 total pass.
**Evidence:**
- Worker exit code: 0
- Tests: 155 hub tests pass (3 new)
- Report: `/opt/termlink/docs/reports/T-903-orchestrator-routing.md`
- Tag convention: `task-type:<type>` (e.g., `task-type:build`)
- Composite key: `method::task_type` for independent cache/bypass tracking

## Decisions

### 2026-04-08 — Routing key strategy
- **Chose:** Composite key `method::task_type` for cache and bypass registry
- **Why:** Separates task-type-specific routes without new data structures, independent promotion tracking
- **Rejected:** Separate task_type field in cache entries (adds schema complexity for no benefit)
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-08T05:32:16Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1064-extend-orchestratorroute-with-task-type-.md
- **Context:** Initial task creation

### 2026-04-08T05:56:43Z — status-update [task-update-agent]
- **Change:** status: captured → started-work
