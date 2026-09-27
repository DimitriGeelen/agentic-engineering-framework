# test_review_paused_resolve

> Tests for /review/T-XXX paused-dispatch panel + resolve endpoint.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_review_paused_resolve.py`

## What It Does

Helpers — mirror tests/unit/test_pause_resolve.py

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [default](/docs/generated/prompts-default) | calls | You are a Worker dispatched by the Agent on the Agentic Engineering Framework. This is the fallback prompt template used when a task_type has no explicit workflow file. |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_review_paused_resolve.yaml`*
*Last verified: 2026-05-13*
