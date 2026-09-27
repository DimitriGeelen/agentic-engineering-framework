# test_reviewer_audit_blueprint

> Unit tests for /reviewer/audit Watchtower route (T-1486).

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_reviewer_audit_blueprint.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [reviewer](/docs/generated/web-blueprints-reviewer) | calls | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [reviewer](/docs/generated/web-blueprints-reviewer) | registers | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | uses | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [shared](/docs/generated/web-shared) | uses | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_reviewer_audit_blueprint.yaml`*
*Last verified: 2026-04-26*
