# test_fabric_graph_cold_load

> T-1770 — /fabric/graph cold-load regression test.

**Type:** script | **Subsystem:** tests-playwright | **Location:** `tests/playwright/test_fabric_graph_cold_load.py`

## What It Does

Allow the deferred requestAnimationFrame init + first ResizeObserver
callback to fire. Two animation frames is enough; 200ms is generous.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [target](/docs/generated/tests-playwright-target) | uses | The one place the Playwright suite decides what it is talking to (T-2784). |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_fabric_graph_cold_load.yaml`*
*Last verified: 2026-05-06*
