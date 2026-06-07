# hook-telemetry

> TODO: describe what this component does

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/hook-telemetry.sh`

## What It Does

lib/hook-telemetry.sh — per-hook fire / failure counters (T-1628, B-2 of T-1626).
Records every Claude Code hook invocation to flat `name=count` files so the
threshold-escalation work in B-3 (T-1629) and `fw doctor` have observable
signal that "non-blocking" hook failures are happening. Without this, hook
breakage is invisible — see T-1626 inception (witness: ring20-dashboard
2026-04-30, dozens of `PostToolUse:Edit hook error / .agentic-framework/bin/fw:
not found` flowed past while every framework health surface reported clean).
Files (in $PROJECT_ROOT/.context/working/):
.hook-counter            — per-hook fire count, one `<hookname>=<count>` line
.hook-failure-counter    — per-hook non-zero-exit count, same format

## Used By (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook_telemetry](/docs/generated/tests-unit-hook_telemetry) | called_by | TODO: describe what this component does |
| [hook_telemetry](/docs/generated/tests-unit-hook_telemetry) | tests_by | TODO: describe what this component does |
| [hook-threshold](/docs/generated/lib-hook-threshold) | called_by | TODO: describe what this component does |

---
*Auto-generated from Component Fabric. Card: `lib-hook-telemetry.yaml`*
*Last verified: 2026-05-01*
