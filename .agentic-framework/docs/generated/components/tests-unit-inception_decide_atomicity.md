# inception_decide_atomicity

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/inception_decide_atomicity.bats`

## What It Does

T-1503: do_inception_decide must be atomic — either fully succeeds (Decision
section + Updates entry + status=work-completed) or leaves the task body
untouched. The original bug: Decision/Updates writes happened BEFORE the
AC gate ran, so a task with custom (non-auto-tick) Agent ACs would have
Decision=GO recorded but status stuck at started-work. Retries then
duplicated the Updates entry.
Live evidence: 003-NTB-ATC-Plugin T-131 watchtower.log:
stdout=...ERROR: Cannot complete — 5/5 agent AC unchecked...
POST /inception/T-131/decide HTTP/1.1 500
Fix (preflight pattern): tick first, count remaining unchecked Agent ACs,

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [colors](/docs/generated/lib-colors) | calls | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | calls | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [tasks](/docs/generated/lib-tasks) | calls | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [inception](/docs/generated/lib-inception) | calls | fw inception - Inception phase workflow |
| [colors](/docs/generated/lib-colors) | tests | Terminal color definitions: BOLD, RED, GREEN, YELLOW, CYAN, NC (no color). Sourced by all framework scripts for consistent output. |
| [errors](/docs/generated/lib-errors) | tests | Consistent error/warning/info output functions with TTY-aware coloring. Provides die(), error(), warn(), info(), success(), block() with standardized exit codes (0=ok, 1=error, 2=blocking). Auto-sourced by lib/paths.sh. |
| [tasks](/docs/generated/lib-tasks) | tests | fw task subcommand dispatcher: routes task create/update/list/verify/review to agents/task-create/ scripts. |
| [inception](/docs/generated/lib-inception) | tests | fw inception - Inception phase workflow |

---
*Auto-generated from Component Fabric. Card: `tests-unit-inception_decide_atomicity.yaml`*
*Last verified: 2026-04-26*
