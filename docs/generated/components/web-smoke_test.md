# smoke_test

> TODO: describe what this component does

**Type:** script | **Subsystem:** watchtower | **Location:** `web/smoke_test.py`

## What It Does

Content markers for critical routes — if the page loads but these are missing,
something is broken (wrong template, missing data, import error).

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [test_smoke](/docs/generated/tests-playwright-test_smoke) | called_by | Playwright smoke tests — all major routes render (T-969) |

---
*Auto-generated from Component Fabric. Card: `web-smoke_test.yaml`*
*Last verified: 2026-09-03*
