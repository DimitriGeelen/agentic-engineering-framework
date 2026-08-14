# sessions_render

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/sessions_render.bats`

## What It Does

T-2417: Generic session renderer — verifies project-grouped tree rendering
from canonical JSONL per agents/sessions/SCHEMA.md.
The renderer is agent-neutral: it never reads CC-specific fields; it consumes
only canonical JSONL. These tests pipe canned JSONL (independent of any
provider) to render.py and assert layout / ordering / formatting.
AC mapping:
t1  empty input → "(no sessions)"
t2  malformed JSONL line → skipped with stderr warning, valid lines still rendered
t3  state subgroup ordering: needs-input → working → completed
t4  project ordering: real projects alphabetical, then (loose) last

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [render](/docs/generated/agents-sessions-render) | calls | TODO: describe what this component does |
| [render](/docs/generated/agents-sessions-render) | tests | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `tests-unit-sessions_render.yaml`*
*Last verified: 2026-06-16*
