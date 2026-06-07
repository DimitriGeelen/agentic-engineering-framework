# hook_absolute_paths

> Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/hook_absolute_paths.bats`

**Tags:** `test`, `hooks`, `settings`, `G-053`, `T-1364`

## What It Does

T-1364 (G-053-A): Unit tests for absolute hook paths in .claude/settings.json.
Claude Code resolves hook commands against the session CWD. When CWD drifts
(test fixtures, subdir navigation), relative paths like "bin/fw hook X"
cascade into tool-blocks. Fix: emit absolute paths at init/upgrade time.
$target_dir is canonicalized via `cd && pwd` in both entry points.

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [hook-config](/docs/generated/hook-config) | reads | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [init](/docs/generated/lib-init) | tests | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_absolute_paths.yaml`*
*Last verified: 2026-04-24*
