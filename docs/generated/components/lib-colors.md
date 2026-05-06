# colors

> Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/colors.sh`

## What It Does

lib/colors.sh — Shared color variables for the Agentic Engineering Framework
Provides TTY-aware, NO_COLOR-respecting color variables.
Replaces inline color definitions duplicated across 20+ scripts.
Usage: source "$FRAMEWORK_ROOT/lib/colors.sh"
Variables: RED, GREEN, YELLOW, CYAN, BOLD, NC
Automatically sourced via lib/errors.sh → lib/paths.sh chain.
Scripts that source lib/paths.sh get colors for free.

## Dependencies (1)

| Target | Relationship |
|--------|-------------|
| `lib/colors.sh` | calls |

## Used By (43)

| Component | Relationship |
|-----------|-------------|
| `lib/colors.sh` | called-by |
| `lib/costs.sh` | called-by |
| `tests/unit/lib_colors.bats` | called-by |
| `agents/handover/handover.sh` | called_by |
| `bin/fw` | called_by |
| `lib/colors.sh` | called_by |
| `lib/costs.sh` | called_by |
| `tests/unit/lib_colors.bats` | called_by |
| `tests/unit/inception_decide_ac_tick.bats` | called_by |
| `tests/unit/inception_decide_ac_tick.bats` | tests_by |
| `tests/unit/inception_decide_atomicity.bats` | called_by |
| `tests/unit/inception_decide_atomicity.bats` | tests_by |
| `tests/unit/inception_tick_decision_recorded.bats` | called_by |
| `tests/unit/inception_tick_decision_recorded.bats` | tests_by |
| `tests/unit/inception_tick_marker.bats` | called_by |
| `tests/unit/inception_tick_marker.bats` | tests_by |
| `tests/unit/lib_assumption.bats` | called_by |
| `tests/unit/lib_assumption.bats` | tests_by |
| `tests/unit/lib_bus.bats` | called_by |
| `tests/unit/lib_bus.bats` | tests_by |
| `tests/unit/lib_colors.bats` | tests_by |
| `tests/unit/lib_dispatch.bats` | called_by |
| `tests/unit/lib_dispatch.bats` | tests_by |
| `tests/unit/lib_harvest.bats` | called_by |
| `tests/unit/lib_harvest.bats` | tests_by |
| `tests/unit/lib_inception.bats` | called_by |
| `tests/unit/lib_inception.bats` | tests_by |
| `tests/unit/lib_init.bats` | called_by |
| `tests/unit/lib_init.bats` | tests_by |
| `tests/unit/lib_pickup.bats` | called_by |
| `tests/unit/lib_pickup.bats` | tests_by |
| `tests/unit/lib_promote.bats` | called_by |
| `tests/unit/lib_promote.bats` | tests_by |
| `tests/unit/lib_review.bats` | called_by |
| `tests/unit/lib_review.bats` | tests_by |
| `tests/unit/lib_setup.bats` | called_by |
| `tests/unit/lib_setup.bats` | tests_by |
| `tests/unit/lib_update.bats` | called_by |
| `tests/unit/lib_update.bats` | tests_by |
| `tests/unit/lib_upgrade.bats` | called_by |
| `tests/unit/lib_upgrade.bats` | tests_by |
| `tests/unit/lib_version.bats` | called_by |
| `tests/unit/lib_version.bats` | tests_by |

## Related

### Tasks
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-colors.yaml`*
*Last verified: 2026-03-11*
