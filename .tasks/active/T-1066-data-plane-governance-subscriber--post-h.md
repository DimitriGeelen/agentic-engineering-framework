---
id: T-1066
name: "Data plane governance subscriber — post-hoc pattern detection on PTY output"
description: >
  Phase 5 from T-1061 (only if validated): Data plane governance subscriber for post-hoc pattern detection on Output frames. Not blocking, not deterministic — useful for audit/metrics. 4-8 weeks.

status: captured
workflow_type: build
owner: human
horizon: later
tags: [termlink, data-plane, audit]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:32Z
last_update: 2026-04-08T05:32:32Z
date_finished: null
---

# T-1066: Data plane governance subscriber — post-hoc pattern detection on PTY output

## Context

Phase 5 from T-1061 inception (GO, only if validated). Data plane governance subscriber that receives Output frames from TermLink's binary frame protocol and performs post-hoc pattern detection. NOT blocking, NOT "deterministic" — useful for audit trail and metrics collection. The data plane already has frame types including Signal (0x3); could add a Governance frame type. Research: `docs/reports/T-1061-termlink-governance-substrate.md`.

**Repo:** TermLink (`/opt/termlink`) — changes in `crates/termlink-session/src/data_server.rs` + `crates/termlink-protocol/src/data.rs`
**Depends on:** T-1063 (MCP governance), validated need for post-hoc detection
**Dispatch:** Execute in TermLink project via `fw termlink dispatch`

## Acceptance Criteria

### Agent
- [ ] New Governance frame type (0x8) added to binary frame protocol
- [ ] Data plane subscriber can receive Output frames and match configurable patterns
- [ ] Pattern matches emit Governance frames back to the session
- [ ] Subscriber is opt-in (not attached by default)
- [ ] Subscriber does NOT block data plane throughput (async, non-blocking)
- [ ] Tests: pattern matching, governance frame emission, throughput non-regression
- [ ] All existing tests pass (`cargo test`)

### Human
- [ ] [REVIEW] Data plane governance design — pattern detection is useful and doesn't degrade performance
  **Steps:**
  1. Review the subscriber architecture and frame protocol changes
  2. Run benchmarks to verify no throughput regression
  3. Evaluate whether detected patterns are actionable
  **Expected:** Non-blocking subscriber, useful pattern detection, no performance impact
  **If not:** Note performance concerns or patterns that aren't actionable

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

### 2026-04-08T05:32:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1066-data-plane-governance-subscriber--post-h.md
- **Context:** Initial task creation
