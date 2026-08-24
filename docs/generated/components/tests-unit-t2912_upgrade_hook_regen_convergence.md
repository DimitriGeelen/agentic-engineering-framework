# t2912_upgrade_hook_regen_convergence

> End-to-end (real fw init'd consumer, env -i) proof that fw upgrade's hook-regeneration step reports its own verified effect instead of the pre-write trigger — a regen that cannot supply a detected-missing hook must report FAILED/PARTIAL, not UPDATED, on every run, and must not write a fresh .bak for a no-op.

**Type:** script | **Subsystem:** upgrade | **Location:** `tests/unit/t2912_upgrade_hook_regen_convergence.bats`

**Tags:** `upgrade`, `hooks`, `convergence`, `e2e`

## What It Does

T-2912 — `fw upgrade` must report the ACTUAL effect of hook regeneration,
not the pre-write trigger. Pre-fix, three consecutive real runs against a
real vendored consumer all printed `UPDATED  Hooks regenerated (missing 7
hook(s): ...)` naming the SAME 7 hooks forever — the regenerator's template
(lib/init.sh generate_claude_code_config) did not know those hooks, so
"regenerate" faithfully reproduced the state the detector complained about.
The adjacent `OK .claude/settings.json (all hooks: ...)` line was a
hardcoded string that never varied with reality, so it agreed with neither
state.
This reproduces the class without waiting for a fresh real drift: it seeds

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [upgrade](/docs/generated/lib-upgrade) | tests | fw upgrade - Sync framework improvements to a consumer project |
| [init](/docs/generated/lib-init) | tests | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2912_upgrade_hook_regen_convergence.yaml`*
*Last verified: 2026-08-10*
