# test_approvals_content_tokens

> T-2026 (arc-007 S3c2): _approvals_content.html inline styles use semantic tokens.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_approvals_content_tokens.py`

## What It Does

DEFER gets warn + dark text in all three blocks

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [_approvals_content](/docs/generated/web-templates-_approvals_content) | calls | htmx partial: approvals content fragment — task list with AC checkboxes, loaded by htmx swap into approvals page. |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_approvals_content_tokens.yaml`*
*Last verified: 2026-05-24*
