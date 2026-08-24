# recall-usage

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/recall-usage.sh`

## What It Does

Recall-usage verdict — T-3019 (T-3005 slice 6a, the "Used" signal).
Sibling to lib/index-health.sh, and extracted for the same reason: a verdict
that can only be exercised by running the whole of `fw doctor` is a verdict
nobody tests twice.
Emits one line: VERDICT|MESSAGE|HINT
OK   — recall was used at least once inside the window
WARN — zero rows in the window (the G-064 zero-consumer signal)
SKIP — web.recall_telemetry not importable (consumer without the extras)
What this checks is deliberately NOT whether recall works. Freshness, liveness
and correctness each have their own control already. This one answers the

## Used By (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `lib-recall-usage.yaml`*
*Last verified: 2026-08-15*
