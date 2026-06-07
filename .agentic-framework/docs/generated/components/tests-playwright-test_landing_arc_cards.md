# test_landing_arc_cards

> Playwright DOM-content assertion (per T-1575/T-971) pinning the landing-page
arc-cards render contract and the /tasks?arc=<id> filter contract after the
T-1850 arc_id migration. Two tests:
- test_landing_arc_cards_show_nonzero_counts: every in-progress arc card
  on / renders with a non-zero task count (arc-005 ≥14); no zero-count
  cards (the migration-blindness regression signal).
- test_tasks_filter_by_arc_returns_members: /tasks?arc=arc-grooming lists
  ≥4 known arc-grooming task IDs.

Re-classifies T-1879's Human [REVIEW] AC to Agent. Origin: T-1879
migration-blindness #2 sweep — 5 sites read arc:<slug> tag only after
the migration stripped them, surfacing zero arc memberships on the
landing page.


**Type:** script | **Subsystem:** testing | **Location:** `tests/playwright/test_landing_arc_cards.py`

**Tags:** `test`, `playwright`, `dom-content`, `arc`, `render-surface`, `T-1879`, `T-1575`, `T-971`

## What It Does

Each card renders "<arc-id> <name> <N> tasks" or " ... 1 task" — pull pairs.
The arc id form is arc-NNN; the count word is "task" or "tasks".
Order in the body text places the id near its count, but a robust scan
finds all (arc-NNN, count) pairs in sequence and joins by adjacency.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [core](/docs/generated/web-blueprints-core) | renders | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | renders | Flask blueprint: Tasks |
| [conftest](/docs/generated/tests-playwright-conftest) | calls | Playwright test fixtures for Watchtower (T-969) |
| [core](/docs/generated/web-blueprints-core) | calls | Flask blueprint: Core |
| [tasks](/docs/generated/web-blueprints-tasks) | calls | Flask blueprint: Tasks |

---
*Auto-generated from Component Fabric. Card: `tests-playwright-test_landing_arc_cards.yaml`*
*Last verified: 2026-05-17*
