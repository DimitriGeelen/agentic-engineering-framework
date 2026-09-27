# overrides

> Reviewer override mechanism (T-1443 v1.4).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/reviewer/overrides.py`

## What It Does

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test_reviewer_overrides](/docs/generated/tests-unit-test_reviewer_overrides) | called_by | Unit tests for lib/reviewer/overrides.py (T-1443 v1.4). |
| [override_cli](/docs/generated/lib-reviewer-override_cli) | called_by | CLI for reviewer overrides (T-1443 v1.4). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | called_by | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |
| [audit](/docs/generated/lib-reviewer-audit) | called_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | called_by | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [audit](/docs/generated/lib-reviewer-audit) | uses_by | Layer 3 audit cron (T-1443 v1.2, T-1484 v1.5b). |
| [override_cli](/docs/generated/lib-reviewer-override_cli) | uses_by | CLI for reviewer overrides (T-1443 v1.4). |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | uses_by | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [reviewer](/docs/generated/web-blueprints-reviewer) | uses_by | Reviewer blueprint — machine-reviewer system state (T-1443 v1.5a). |

---
*Auto-generated from Component Fabric. Card: `lib-reviewer-overrides.yaml`*
*Last verified: 2026-04-25*
