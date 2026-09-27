# test_inception_close_card

> T-3180: a decided inception must have a way to close it.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_inception_close_card.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [inception](/docs/generated/web-blueprints-inception) | calls | Blueprint 'inception' — routes: /inception |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [decided_unclosed](/docs/generated/lib-decided_unclosed) | calls | T-3175: inceptions that are DECIDED but still open — the queue nobody showed. |
| [inception](/docs/generated/web-blueprints-inception) | registers | Blueprint 'inception' — routes: /inception |
| [inception](/docs/generated/web-blueprints-inception) | uses | Blueprint 'inception' — routes: /inception |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_inception_close_card.yaml`*
*Last verified: 2026-08-26*
