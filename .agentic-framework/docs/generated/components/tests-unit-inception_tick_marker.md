# inception_tick_marker

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/inception_tick_marker.bats`

## What It Does

T-1472 (OBS-019 Level D): tick_inception_decide_acs detects ceremonial
ACs via `<!-- @auto-tick-on-decide -->` markers — text-wording independent.
Replaces the AGENT_PATTERNS regex fragility that caused T-1455's GO 500
(T-1466 RCA) — every new AC wording variant required extending the regex.

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
*Auto-generated from Component Fabric. Card: `tests-unit-inception_tick_marker.yaml`*
*Last verified: 2026-04-25*
