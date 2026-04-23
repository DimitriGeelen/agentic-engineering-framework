---
id: T-1065
name: "Multi-LLM routing — task-aware model selection via TermLink dispatch"
description: >
  Phase 4 from T-1061: Task-aware model selection with dispatch system spawning per-model workers. Extends Phase 3 orchestrator routing. 2-3 months.

status: captured
workflow_type: build
owner: human
horizon: next
tags: [termlink, multi-llm, routing]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:25Z
last_update: 2026-04-23T16:46:48Z
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
- [ ] Route cache tracks model -> task-type success rates (future — not part of model passthrough)
- [ ] Circuit breaker handles model unavailability with fallback to next model (future)
- [x] Default behavior (no model specified) is unchanged
- [x] Tests: model dispatch (3 tests pass: opus, sonnet, absent)
- [x] All existing tests pass (`cargo test`)

### Human
- [ ] [REVIEW] Multi-LLM routing design — model selection strategy is sound and cost-effective
  **Steps:**
  1. Review the routing logic and model selection heuristics
  2. Verify fallback chain is sensible (e.g., opus -> sonnet -> haiku)
  3. Check that cost implications are considered (route cheap tasks to cheap models)
  **Expected:** Clean model routing with intelligent defaults
  **If not:** Note where the cost model is wrong or where routing decisions are opaque

## Verification

# Runs in /opt/termlink
# cd /opt/termlink && cargo test
# cd /opt/termlink && cargo build
# The completion gate runs each command — if any exits non-zero, completion is blocked.

## Recommendation

**Recommendation:** Partial complete — model passthrough done, routing intelligence deferred
**Rationale:** The model parameter was already implemented in TermLink's dispatch system (CLI --model flag, MCP model param, TERMLINK_MODEL env var, manifest recording). Route cache model tracking and circuit breaker model fallback remain as future work.
**Evidence:**
- Worker exit code: 0
- Report: `/opt/termlink/docs/reports/T-906-model-param-dispatch.md`
- 5 integration points verified: MCP param, MCP env, CLI flag, CLI env, manifest
- 3 tests pass: dispatch with opus, dispatch with sonnet, dispatch without model
- Route cache + circuit breaker model intelligence not yet implemented (separate task)

## Decisions

### 2026-04-08 — Model routing scope split
- **Chose:** Model passthrough first, routing intelligence later
- **Why:** Model passthrough is the foundation. Route cache model tracking and circuit breaker fallback are separate concerns that build on it.
- **Rejected:** Implementing full model routing in one task (timed out on first attempt, scope too large)

## Updates

### 2026-04-08T05:32:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1065-multi-llm-routing--task-aware-model-sele.md
- **Context:** Initial task creation

### 2026-04-08T06:54:54Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T16:46:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next
