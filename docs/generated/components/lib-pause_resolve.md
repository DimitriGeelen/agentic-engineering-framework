# pause_resolve

> Pause re-dispatch chain — capture operator's answer + fire a retry via Resolver.

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/pause_resolve.py`

## What It Does

resolver lives next to this file in lib/.

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [resolver](/docs/generated/lib-resolver) | uses | Resolver — workflow lookup, prompt assembly, variant selection, telemetry. |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [pause_cli](/docs/generated/lib-pause_cli) | uses_by | CLI dispatcher for `fw pause`. T-1809 (dispatch-safety slice 5). |
| [test_pause_resolve](/docs/generated/tests-unit-test_pause_resolve) | called_by | Tests for lib/pause_resolve.py — operator-answer capture + re-dispatch. |

---
*Auto-generated from Component Fabric. Card: `lib-pause_resolve.yaml`*
*Last verified: 2026-05-13*
