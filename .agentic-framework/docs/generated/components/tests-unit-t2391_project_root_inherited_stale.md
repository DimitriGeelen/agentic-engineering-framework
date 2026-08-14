# t2391_project_root_inherited_stale

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t2391_project_root_inherited_stale.bats`

## What It Does

T-2391: bin/fw validates an INHERITED (non-empty) PROJECT_ROOT and re-resolves
when stale, instead of using it verbatim. Origin: T-2389/T-2390 live-fire — the
tmux-server daemon (PID 6177) carries a stale PROJECT_ROOT=$HOME (/root) in its
env; every spawned session inherited it, the `-z` guard short-circuited, the
poison was used as-is, and the budget gauge went blind (continuous loop never
armed). The T-2390 CLAUDE_PROJECT_DIR-preference block was dead code in that path.
Surface under test: bin/fw "_project_root_is_stale" + "Resolve PROJECT_ROOT"
block. Observed via `fw version` ("Project: <root>"), same harness as
t2390_project_root_claude_dir.bats.
Staleness is NARROW (preserve "env wins" for legitimate overrides):

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t2391_project_root_inherited_stale.yaml`*
*Last verified: 2026-06-14*
