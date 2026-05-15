# test_arc_system

> Unit tests for fw arc CLI (T-1661 Phase 1 MVP) — pins create/focus/list/show/tag/close/migrate verbs, anchor handling, and handover injection of ## Current Arc section.

**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/test_arc_system.py`

**Tags:** `arcs`, `regression`, `t-1661`

## What It Does

T-1671: clear CLAUDECODE so arc-close tests run as human invocation
(CLAUDECODE-aware tests live in test_arc_close_agent_gate.py with
explicit env_extra={"CLAUDECODE": "1"} where needed).

## Dependencies (3)

| Target | Relationship |
|--------|-------------|
| `bin/fw` | calls |
| `lib/arc.sh` | calls |
| `agents/handover/handover.sh` | calls |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_arc_system.yaml`*
*Last verified: 2026-05-01*
