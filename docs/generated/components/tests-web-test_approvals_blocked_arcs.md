# test_approvals_blocked_arcs

> T-2986: an arc that meets the closure threshold but is not reviewable says so.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_approvals_blocked_arcs.py`

## What It Does

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [approvals](/docs/generated/web-blueprints-approvals) | calls | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | registers | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [approvals](/docs/generated/web-blueprints-approvals) | uses | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_approvals_blocked_arcs.yaml`*
*Last verified: 2026-08-14*
