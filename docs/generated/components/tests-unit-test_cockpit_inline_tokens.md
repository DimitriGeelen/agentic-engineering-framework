# test_cockpit_inline_tokens

> T-2024 (arc-007 S3a2): cockpit inline-style hexes use per-palette semantic tokens.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_cockpit_inline_tokens.py`

## What It Does

old fixed hexes gone from the card rules

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [cockpit](/docs/generated/web-templates-cockpit) | calls | Page template: Watchtower |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_cockpit_inline_tokens.yaml`*
*Last verified: 2026-05-24*
