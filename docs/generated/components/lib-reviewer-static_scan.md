# static_scan

> Static-scan reviewer (T-1443 v1.0 → v1.5).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/static_scan.py`

## What It Does

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [overrides](/docs/generated/lib-reviewer-overrides) | calls | Reviewer override mechanism (T-1443 v1.4). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [recommendation_claims](/docs/generated/lib-reviewer-recommendation_claims) | calls | T-100187: Recommendation-claims validator (T-100186 GO slice A). |
| [overrides](/docs/generated/lib-reviewer-overrides) | uses | Reviewer override mechanism (T-1443 v1.4). |
| [recommendation_claims](/docs/generated/lib-reviewer-recommendation_claims) | uses | T-100187: Recommendation-claims validator (T-100186 GO slice A). |

## Used By (10)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | called_by | Task Update Agent - Status transitions with auto-triggers |
| [audit](/docs/generated/lib-reviewer-audit) | called_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [drift_cli](/docs/generated/lib-reviewer-drift_cli) | called_by | CLI shim for drift detection (T-1483 v1.5 Pass A). |
| [audit-swallowed-errors](/docs/generated/tools-audit-swallowed-errors) | called_by | L-369 corpus audit: scan all task ## Verification blocks for swallowed-errors findings using the reviewer's deterministic detector. |
| [g066_readiness](/docs/generated/tests-unit-g066_readiness) | tests_by | T-2198: G-066 closure-readiness gauge — covers READY against live repo, NOT_READY when each wiring leg is absent, and --strict exit-code semantics. |
| [g066-readiness](/docs/generated/tools-g066-readiness) | called_by | G-066 closure-readiness gauge — wiring-presence check. |
| [shared](/docs/generated/web-shared) | called_by | Shared helpers for all web blueprints — path resolution, navigation groups, ambient status strip, render_page (htmx/full page rendering) |
| [audit](/docs/generated/lib-reviewer-audit) | uses_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [drift_cli](/docs/generated/lib-reviewer-drift_cli) | uses_by | CLI shim for drift detection (T-1483 v1.5 Pass A). |
| [audit-swallowed-errors](/docs/generated/tools-audit-swallowed-errors) | uses_by | L-369 corpus audit: scan all task ## Verification blocks for swallowed-errors findings using the reviewer's deterministic detector. |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-static_scan.yaml`*
*Last verified: 2026-05-06*
