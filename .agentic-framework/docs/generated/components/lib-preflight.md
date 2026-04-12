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

| Target | Relationship |
|--------|-------------|
| `?` | uses |

## Used By (4)

| Component | Relationship |
|-----------|-------------|
| `bin/fw` | called_by |
| `lib/init.sh` | called_by |
| `tests/unit/lib_preflight.bats` | called-by |
| `tests/unit/lib_preflight.bats` | called_by |

---
*Auto-generated from Component Fabric. Card: `lib-preflight.yaml`*
*Last verified: 2026-03-04*
