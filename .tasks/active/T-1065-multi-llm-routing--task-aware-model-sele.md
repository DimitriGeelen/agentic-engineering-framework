---
id: T-1065
name: "Multi-LLM routing — task-aware model selection via TermLink dispatch"
description: >
  Phase 4 from T-1061: Task-aware model selection with dispatch system spawning per-model workers. Extends Phase 3 orchestrator routing. 2-3 months.

status: captured
workflow_type: build
owner: human
horizon: later
tags: [termlink, multi-llm, routing]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:25Z
last_update: 2026-04-08T05:32:25Z
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
- [ ] `termlink_dispatch` MCP tool accepts `model` parameter (e.g., "opus", "sonnet", "haiku")
- [ ] Dispatch system spawns workers with model-specific configuration
- [ ] Route cache tracks model -> task-type success rates
- [ ] Circuit breaker handles model unavailability with fallback to next model
- [ ] Default behavior (no model specified) is unchanged
- [ ] Tests: model dispatch, model fallback, success rate tracking
- [ ] All existing tests pass (`cargo test`)

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

## Decisions

<!-- Record decisions ONLY when choosing between alternatives.
     Skip for tasks with no meaningful choices.
     Format:
     ### [date] — [topic]
     - **Chose:** [what was decided]
     - **Why:** [rationale]
     - **Rejected:** [alternatives and why not]
-->

## Updates

### 2026-04-08T05:32:25Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1065-multi-llm-routing--task-aware-model-sele.md
- **Context:** Initial task creation
