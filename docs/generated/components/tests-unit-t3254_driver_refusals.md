# t3254_driver_refusals

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3254_driver_refusals.bats`

## What It Does

T-3254 (arc-012) — the outside driver must refuse on every armed condition.
WHAT IS UNDER TEST AND WHY IT IS SPLIT IN TWO. This task flips the loop's default
from stop-on-silence to continue-unless-done, so the refusals ARE the safety
argument. There are two units:
Part A — `fw continuous status --json`, the single evaluator. The driver does
not re-type the bounds; it reads this verdict. So the six armed conditions
are tested HERE, against the thing that actually decides.
Part B — `continuous-driver.sh`, for the one condition the evaluator cannot
reach: whether the target session is busy. TermLink has no busy state
(measured: `discover --json` says state="ready" for 127 of 127 registered

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [continuous-driver](/docs/generated/agents-context-continuous-driver) | tests | TODO: describe what this component does |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3254_driver_refusals.yaml`*
*Last verified: 2026-09-03*
