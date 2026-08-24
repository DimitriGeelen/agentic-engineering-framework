# doctor_hook_counters

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/doctor_hook_counters.bats`

## What It Does

T-2714 (OBS-110): every hook counter in `fw doctor` must state its denominator.
One doctor run printed four numbers for one settings.json — 25, 21, 19, 23 —
three of them under the bare word "hooks". The 19 was wrong outright:
sum(len(v) for v in hooks.values()) sums each event's list of MATCHER ENTRIES,
and every entry carries a `hooks:` array of 1..n commands. So it counted matchers
and called them hooks, and disagreed with the line three rows above it that counts
commands correctly — leaving an operator checking a post-regenerate config (the
T-2710 class) no way to tell which number was lying.
TEST DESIGN — the fixture is the whole point.
A test written against this repo's live settings.json cannot tell the fix from the

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-doctor_hook_counters.yaml`*
*Last verified: 2026-08-01*
