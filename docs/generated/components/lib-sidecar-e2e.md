# e2e

> arc-011 sidecar — live end-to-end harness (T-3423, slice 9).

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/sidecar/e2e.py`

## What It Does

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [sidecar_cli](/docs/generated/lib-sidecar_cli) | called_by | `fw sidecar` — the callable surface of the arc-011 peer-consult sidecar. |
| [test_sidecar_e2e](/docs/generated/tests-unit-test_sidecar_e2e) | uses_by | T-3423 — arc-011 sidecar slice 9: the end-to-end harness state machine. |

---
*Auto-generated from Component Fabric. Card: `lib-sidecar-e2e.yaml`*
*Last verified: 2026-09-22*
