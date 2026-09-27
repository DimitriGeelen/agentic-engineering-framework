# hook-threshold

> T-1631 (B-3b of T-1626) — hook-failure threshold rule.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook-threshold.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-telemetry](/docs/generated/lib-hook-telemetry) | calls | lib/hook-telemetry.sh — per-hook fire / failure counters (T-1628, B-2 of T-1626). |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [hook_threshold](/docs/generated/tests-unit-hook_threshold) | called_by | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [hook_threshold](/docs/generated/tests-unit-hook_threshold) | tests_by | T-1631 (B-3b of T-1626) — hook-failure threshold rule. |
| [hooks](/docs/generated/web-blueprints-hooks) | called_by | T-1632 (B-3c of T-1626) — Watchtower /hooks page. |
| [write_set](/docs/generated/lib-write_set) | called_by | Disjoint write-set policy validator (T-2337, arc-011 M1 §3). |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |

---
*Auto-generated from Component Fabric. Card: `lib-hook-threshold.yaml`*
*Last verified: 2026-05-01*
