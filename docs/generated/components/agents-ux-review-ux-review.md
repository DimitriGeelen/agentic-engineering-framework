# ux-review

> UX-review capture engine (T-2002): drives Watchtower render surfaces in a headless browser across every appearance preset and produces visual review artifacts for human review.

**Type:** script | **Subsystem:** watchtower | **Location:** `agents/ux-review/ux-review.py`

## What It Does

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [app](/docs/generated/web-app) | calls | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [foundations](/docs/generated/web-static-css-foundations) | calls | Watchtower Foundation Tokens — arc-007 (watchtower-redesign) slice S0, T-1991 Source: docs/design/watchtower-redesign-2026-05-13/project/foundations.jsx |
| [app](/docs/generated/web-app) | uses | Flask application entrypoint — creates app, registers all blueprints, serves Watchtower web UI on configurable port |

## Used By (13)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_all_routes_height](/docs/generated/tests-playwright-test_all_routes_height) | called_by | Exhaustive all-routes height guard (T-2048). |
| [test_approvals_height](/docs/generated/tests-playwright-test_approvals_height) | called_by | Playwright regression test for /approvals rendered height (T-2038). |
| [test_decisions_height](/docs/generated/tests-playwright-test_decisions_height) | called_by | Playwright regression test for /decisions rendered height (T-2045). |
| [test_docs_generated_height](/docs/generated/tests-playwright-test_docs_generated_height) | called_by | Playwright regression test for /docs/generated rendered height (T-2047). |
| [test_fabric_height](/docs/generated/tests-playwright-test_fabric_height) | called_by | Playwright regression test for /fabric rendered height (T-2039). |
| [test_gaps_height](/docs/generated/tests-playwright-test_gaps_height) | called_by | Playwright regression test for /gaps rendered height (T-2043). |
| [test_graduation_height](/docs/generated/tests-playwright-test_graduation_height) | called_by | Playwright regression test for /graduation rendered height (T-2046). |
| [test_inception_height](/docs/generated/tests-playwright-test_inception_height) | called_by | Playwright regression test for /inception rendered height (T-2040). |
| [test_learnings_height](/docs/generated/tests-playwright-test_learnings_height) | called_by | Playwright regression test for /learnings rendered height (T-2044). |
| [test_timeline_height](/docs/generated/tests-playwright-test_timeline_height) | called_by | Playwright regression test for /timeline rendered height (T-2041). |
| [review_link_validator](/docs/generated/lib-review_link_validator) | called_by | Validate Watchtower review/inception handoff links at the moment of handoff. |
| [test_ux_review_routes](/docs/generated/tests-unit-test_ux_review_routes) | called_by | Unit test for ux-review route discovery (T-2042). |
| [test_all_routes_size](/docs/generated/tests-playwright-test_all_routes_size) | called_by | Exhaustive all-routes response-SIZE guard (T-2775). |

---
*Auto-generated from Component Fabric. Card: `agents-ux-review-ux-review.yaml`*
*Last verified: 2026-05-23*
