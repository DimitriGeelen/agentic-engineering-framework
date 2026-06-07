# test_upgrade_downgrade_guard

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_upgrade_downgrade_guard.bats`

## What It Does

T-1839 — fw upgrade silent-downgrade guard.
Origin: T-1838 (sibling) fixed the doctor advice that would have pointed
operators at a downgrading `fw upgrade`. T-1839 closes the loop by making
the command itself refuse the downgrade direction unless explicitly
overridden with --force-downgrade.
Pre-fix behaviour (lib/upgrade.sh:1082-1112): direction-blind overwrite of
.framework.yaml's `version:` field with $FW_VERSION whenever the two
differ. Consumer at 1.6.260 + framework at 1.6.170 → silent downgrade,
only post-facto forensic trail in `upgraded_from` + audit YAML.
These tests pin:

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_upgrade_downgrade_guard.yaml`*
*Last verified: 2026-05-14*
