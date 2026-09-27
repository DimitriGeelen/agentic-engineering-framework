# review_link_validator

> Validate Watchtower review/inception handoff links at the moment of handoff.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/review_link_validator.py`

## What It Does

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [ux-review](/docs/generated/agents-ux-review-ux-review) | calls | UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_review_link_validator](/docs/generated/tests-unit-test_review_link_validator) | called_by | T-2050 — unit tests for lib/review_link_validator.py. |
| [review_link_blocking_gate](/docs/generated/tests-unit-review_link_blocking_gate) | tests_by | T-2139 V1 keystone — emit_review blocking gate on review-link homework. |

---
*Auto-generated from Component Fabric. Card: `lib-review_link_validator.yaml`*
*Last verified: 2026-05-25*
