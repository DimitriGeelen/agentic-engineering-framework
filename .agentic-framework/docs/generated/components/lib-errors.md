# errors

> Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/errors.sh`

**Tags:** `shell`, `errors`, `output`, `usability`, `core`

## What It Does

lib/errors.sh — Consistent error/warning/info output for the framework
Provides colored, TTY-aware output functions with standardized exit codes.
Replaces ad-hoc echo/exit patterns across 25+ agent scripts.
Usage: source "$FRAMEWORK_ROOT/lib/errors.sh"
Functions:
die MESSAGE [EXIT_CODE]   — Print error and exit (default: 1)
error MESSAGE             — Print error to stderr (no exit)
warn MESSAGE              — Print warning to stderr
info MESSAGE              — Print info to stdout
success MESSAGE           — Print success to stdout

## Used By (34)

| Component | Relationship |
|-----------|-------------|
| `lib/paths.sh` | calls |
| `agents/task-create/create-task.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `agents/handover/handover.sh` | calls |
| `agents/healing/healing.sh` | calls |
| `agents/context/context.sh` | calls |
| `lib/paths.sh` | called_by |
| `tests/unit/lib_errors.bats` | called-by |
| `tests/unit/lib_errors.bats` | called_by |
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
| `tests/unit/lib_dispatch.bats` | called_by |
| `tests/unit/lib_dispatch.bats` | tests_by |
| `tests/unit/lib_errors.bats` | tests_by |
| `tests/unit/lib_inception.bats` | called_by |
| `tests/unit/lib_inception.bats` | tests_by |
| `tests/unit/lib_init.bats` | called_by |
| `tests/unit/lib_init.bats` | tests_by |
| `tests/unit/lib_setup.bats` | called_by |
| `tests/unit/lib_setup.bats` | tests_by |
| `tests/unit/lib_update.bats` | called_by |
| `tests/unit/lib_update.bats` | tests_by |
| `tests/unit/lib_version.bats` | called_by |
| `tests/unit/lib_version.bats` | tests_by |

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-errors.yaml`*
*Last verified: 2026-03-10*
