# verify_queue

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/verify_queue.py`

## What It Does

Lines we refuse to execute. CTL-013 already skips nested audit invocations
(L-391); scaling from 3 tasks to the whole queue widens the blast radius
enough that "skip and say so" beats "run and hope". Reported as SKIPPED, never
as PASS — a skip that reads as a pass is the vacuous-green class this rail
exists to remove.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verification-port](/docs/generated/lib-verification-port) | calls | TODO: describe what this component does |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | called_by | TODO: describe what this component does |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-verify_queue.yaml`*
*Last verified: 2026-08-03*
