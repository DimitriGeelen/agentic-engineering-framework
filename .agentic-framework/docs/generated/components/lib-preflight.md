# preflight

> fw preflight subcommand. Validates system prerequisites (bash version, git version, python3, PyYAML) before framework operations.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/preflight.sh`

**Tags:** `lib`, `fw-subcommand`, `validation`

## What It Does

fw preflight — Validate OS dependencies before init
Sovereignty principle: detect silently, inform clearly, act only with consent.
Same pattern as Tier 0: detect → inform → ask → execute with approval.
Usage:
fw preflight              # Interactive: check + offer to install
fw preflight --check-only # Non-interactive: check only, exit code 0/1
Exit codes:
0 = all required deps present
1 = required dep(s) missing

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| `?` | uses | — |

## Used By (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [init](/docs/generated/lib-init) | called_by | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [lib_preflight](/docs/generated/tests-unit-lib_preflight) | called-by | Unit tests for preflight (11 tests) |
| [lib_preflight](/docs/generated/tests-unit-lib_preflight) | called_by | Unit tests for preflight (11 tests) |
| [lib_preflight](/docs/generated/tests-unit-lib_preflight) | tests_by | Unit tests for preflight (11 tests) |

---
*Auto-generated from Component Fabric. Card: `lib-preflight.yaml`*
*Last verified: 2026-03-04*
