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

## Used By (9)

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

## Related

### Tasks
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `lib-errors.yaml`*
*Last verified: 2026-03-10*
