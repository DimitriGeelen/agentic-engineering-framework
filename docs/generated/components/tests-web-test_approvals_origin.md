# test_approvals_origin

> T-3078: /approvals must not assert an agent asked when none did.

**Type:** script | **Subsystem:** tests | **Location:** `tests/web/test_approvals_origin.py`

## What It Does

── the derived subtitle ───────────────────────────────────────────────────

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [approvals](/docs/generated/web-blueprints-approvals) | calls | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [approvals](/docs/generated/web-blueprints-approvals) | registers | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [approvals](/docs/generated/web-blueprints-approvals) | uses | Watchtower approvals blueprint: human review queue — lists tasks with unchecked Human ACs, supports checkbox toggling. |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-web-test_approvals_origin.yaml`*
*Last verified: 2026-08-19*
