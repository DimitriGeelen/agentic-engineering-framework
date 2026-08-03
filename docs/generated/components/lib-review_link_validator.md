# review_link_validator

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/review_link_validator.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [ux-review](/docs/generated/agents-ux-review-ux-review) | calls | TODO: describe what this component does |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_review_link_validator](/docs/generated/tests-unit-test_review_link_validator) | called_by | TODO: describe what this component does |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-review_link_validator.yaml`*
*Last verified: 2026-05-25*
