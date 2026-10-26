# t4729_agent_dispatch_counter

> T-4729 — check-agent-dispatch.sh counted blocked attempts and never reset per session (reported by 010-termlink, TermLink T-2981 2a). The counter now counts only allowed dispatches and is keyed to the session id.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t4729_agent_dispatch_counter.bats`

## What It Does

T-4729 — check-agent-dispatch.sh counted blocked attempts and never reset per
session (reported by 010-termlink, TermLink T-2981 2a). The counter now counts
only allowed dispatches and is keyed to the session id.

---
*Auto-generated from Component Fabric. Card: `tests-unit-t4729_agent_dispatch_counter.yaml`*
*Last verified: 2026-10-25*
