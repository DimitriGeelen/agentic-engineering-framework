# outside_commits

> Outside-commit alarm (T-5049, requirement R-58).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/outside_commits.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `policy/internal-identities.yaml` | reads | — |

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | calls | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| `lib/operator_pending.py` | calls | — |

---
*Auto-generated from Component Fabric. Card: `lib-outside_commits.yaml`*
*Last verified: 2026-11-03*
