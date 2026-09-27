# test_session_cookie_port

> T-3065: the session cookie is named for the port actually being served.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/test_session_cookie_port.py`

## What It Does

Mirror main()'s ordering: build-time default, then flag override.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_session_cookie_port.yaml`*
*Last verified: 2026-08-17*
