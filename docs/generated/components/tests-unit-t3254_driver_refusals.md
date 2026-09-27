# t3254_driver_refusals

> T-3254 (arc-012) — the outside driver must refuse on every armed condition.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/t3254_driver_refusals.bats`

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
| [continuous-driver](/docs/generated/agents-context-continuous-driver) | tests | T-3254 (arc-012) — drive the loop from OUTSIDE when the agent stops early. |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | tests | T-2364/T-2365 (T-2158 S2+S3) — next-directive injector for post-compact resume. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3254_driver_refusals.yaml`*
*Last verified: 2026-09-03*
