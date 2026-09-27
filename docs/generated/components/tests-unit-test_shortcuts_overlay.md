# test_shortcuts_overlay

> T-2013 (arc-007 S6b): keyboard-shortcuts overlay — server-side presence.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_shortcuts_overlay.py`

## What It Does

each live shortcut's description must be in the rendered cheat-sheet

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_shortcuts_overlay.yaml`*
*Last verified: 2026-05-23*
