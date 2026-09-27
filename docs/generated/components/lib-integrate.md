# integrate

> fw integrate — Layer 2 serialized-integration preflight (T-2399, T-2397 slice 1).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/integrate.py`

## What It Does

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [branch-hygiene](/docs/generated/lib-branch-hygiene) | calls | lib/branch-hygiene.sh — T-100143 (C2 of T-100139 branch/worktree lifecycle GO) |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t2399_integrate_check](/docs/generated/tests-unit-t2399_integrate_check) | tests_by | T-2399: fw integrate check — L2 serialized-integration preflight (read-only). |
| [t2473_union_resolve](/docs/generated/tests-unit-t2473_union_resolve) | called_by | T-2473 — fw integrate run: true per-class UNION at both-sided conflicts. |
| [t2473_union_resolve](/docs/generated/tests-unit-t2473_union_resolve) | tests_by | T-2473 — fw integrate run: true per-class UNION at both-sided conflicts. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-integrate.yaml`*
*Last verified: 2026-06-14*
