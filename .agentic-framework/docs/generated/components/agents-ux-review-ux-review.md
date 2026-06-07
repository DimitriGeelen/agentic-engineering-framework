# ux-review

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `agents/ux-review/ux-review.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_all_routes_height](/docs/generated/tests-playwright-test_all_routes_height) | called_by | TODO: describe what this component does |
| [test_approvals_height](/docs/generated/tests-playwright-test_approvals_height) | called_by | TODO: describe what this component does |
| [test_decisions_height](/docs/generated/tests-playwright-test_decisions_height) | called_by | TODO: describe what this component does |
| [test_docs_generated_height](/docs/generated/tests-playwright-test_docs_generated_height) | called_by | TODO: describe what this component does |
| [test_fabric_height](/docs/generated/tests-playwright-test_fabric_height) | called_by | TODO: describe what this component does |
| [test_gaps_height](/docs/generated/tests-playwright-test_gaps_height) | called_by | TODO: describe what this component does |
| [test_graduation_height](/docs/generated/tests-playwright-test_graduation_height) | called_by | TODO: describe what this component does |
| [test_inception_height](/docs/generated/tests-playwright-test_inception_height) | called_by | TODO: describe what this component does |
| [test_learnings_height](/docs/generated/tests-playwright-test_learnings_height) | called_by | TODO: describe what this component does |
| [test_timeline_height](/docs/generated/tests-playwright-test_timeline_height) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-ux-review-ux-review.yaml`*
*Last verified: 2026-05-23*
