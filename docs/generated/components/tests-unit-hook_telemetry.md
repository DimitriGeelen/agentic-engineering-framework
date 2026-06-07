# hook_telemetry

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/hook_telemetry.bats`

## What It Does

T-1628 (B-2 of T-1626) — per-hook fire / failure counters.
Pins the contract that:
1. Every hook invocation increments .hook-counter[hookname]
2. Non-zero exits also increment .hook-failure-counter[hookname]
3. Files self-create on first fire — no init needed
4. Telemetry never blocks the hook (read-only fs / missing dir = silent 0)
5. Per-fire overhead stays under 5ms (T-1626 constraint)
6. The `bin/fw hook` dispatcher is wired to call fw_record_hook_fire
Origin: T-1626 inception (ring20-dashboard 2026-04-30) — dozens of hook
failures flowed past while framework reported clean. Telemetry is the

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-telemetry](/docs/generated/lib-hook-telemetry) | calls | TODO: describe what this component does |
| [hook-telemetry](/docs/generated/lib-hook-telemetry) | tests | TODO: describe what this component does |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_telemetry.yaml`*
*Last verified: 2026-05-01*
