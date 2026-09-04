# continuous-driver

> TODO: describe what this component does

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/continuous-driver.sh`

## What It Does

T-3254 (arc-012) — drive the loop from OUTSIDE when the agent stops early.
THE HOLE THIS FILLS. The live ledger records three `exit no-signal` entries: the
loop simply ended, not because the backlog was empty but because the agent stopped
before filling 285K tokens. Continuity depended on the agent being wasteful enough
to hit the wall, which is backwards.
M1 (Stop-hook continuation) is capped at exactly ONE turn — stop_hook_active is
honoured ahead of every cap we own, and Claude Code sets it on any stop that
follows a hook-driven continuation (measured, T-3239 E2).
M2 (budget compact-resume) fires only at budget-critical — the wrong trigger for
"the agent stopped early".

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [t3254_driver_refusals](/docs/generated/tests-unit-t3254_driver_refusals) | tests_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `agents-context-continuous-driver.yaml`*
*Last verified: 2026-09-03*
