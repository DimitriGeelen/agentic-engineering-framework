# t3254-livefire

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tools/t3254-livefire.sh`

## What It Does

T-3254 (arc-012) AC5 + AC6 — live-fire and its negative control.
WHAT IS BEING PROVEN. The loop's failure mode is `exit no-signal`: the agent stops
before the budget gauge trips, backlog remaining, and nothing restarts it. M2 cannot
reach that case because it triggers on budget-critical. This drives a session that
has stopped early, to completion, using the cron path alone — with the budget gauge
never consulted, let alone tripped.
WHY THE NEGATIVE CONTROL IS NOT OPTIONAL. Without it, "the driver continued the
work" and "the work finished on its own" produce identical evidence. That
indistinguishability is what made the E9 ceiling result meaningless, and it is the
single most repeated failure in this arc. So the identical run is repeated with

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tools-t3254-livefire.yaml`*
*Last verified: 2026-09-03*
