---
id: T-1066
name: "Data plane governance subscriber — post-hoc pattern detection on PTY output"
description: >
  Phase 5 from T-1061 (only if validated): Data plane governance subscriber for post-hoc pattern detection on Output frames. Not blocking, not deterministic — useful for audit/metrics. 4-8 weeks.

status: captured
workflow_type: build
owner: human
horizon: next
tags: [termlink, data-plane, audit]
components: []
related_tasks: [T-1061]
created: 2026-04-08T05:32:32Z
last_update: 2026-04-23T16:46:48Z
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
- [x] New Governance frame type (0x8) added to binary frame protocol
- [x] Data plane subscriber can receive Output frames and match configurable patterns
- [x] Pattern matches emit Governance frames back to the session
- [x] Subscriber is opt-in (not attached by default)
- [x] Subscriber does NOT block data plane throughput (async, non-blocking)
- [x] Tests: pattern matching, governance frame emission, throughput non-regression
- [x] All existing tests pass (`cargo test`) — 250 session + 92 protocol pass

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

## Recommendation

**Recommendation:** GO

**Rationale:** All 7 Agent ACs verified satisfied via TermLink-side T-905 worker. New Governance frame type (0x8) added to binary protocol, opt-in non-blocking subscriber receives Output frames and matches configurable patterns, emits Governance frames back to session, async/non-blocking design preserves data plane throughput. 9 new tests; 250 session + 92 protocol tests pass (342 total). Awaits Human [REVIEW] of architectural design + benchmark validation.

**Evidence:**
- Worker exit code: 0
- Tests: 250 session + 92 protocol = 342 pass (9 new governance-specific)
- Report: `/opt/termlink/docs/reports/T-905-data-plane-governance.md`
- Architecture: broadcast channel -> ANSI strip -> regex match -> mpsc Governance frame
- New files: `governance.rs` (protocol), `governance_subscriber.rs` (session)
- New dependency: `regex = "1"` (workspace)

## Decisions

### 2026-04-08 — Subscriber channel architecture
- **Chose:** Broadcast channel for input, bounded mpsc (256) for output
- **Why:** Broadcast gives subscriber a copy without blocking data plane; bounded mpsc prevents memory leak if nobody reads governance frames
- **Rejected:** Unbounded channels (memory risk), direct write to data plane (blocking risk)

## Updates

### 2026-04-08T05:32:32Z — task-created [task-create-agent]
- **Action:** Created task via task-create agent
- **Output:** /opt/999-Agentic-Engineering-Framework/.tasks/active/T-1066-data-plane-governance-subscriber--post-h.md
- **Context:** Initial task creation

### 2026-04-08T06:55:34Z — status-update [task-update-agent]
- **Change:** status: captured → started-work

### 2026-04-23T16:46:48Z — status-update [task-update-agent]
- **Change:** horizon: later → next
