# hook_absolute_paths

> Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts.

**Type:** script | **Subsystem:** tests | **Location:** `tests/unit/hook_absolute_paths.bats`

**Tags:** `test`, `hooks`, `settings`, `G-053`, `T-1364`

## What It Does

T-1364 (G-053-A) / T-1504: hook commands in .claude/settings.json must resolve
INDEPENDENTLY OF CWD. Claude Code's hook runner (POSIX sh -c) does not chdir to the
project root, so a bare-relative command like "bin/fw hook X" only resolves when the
parent shell happens to be at project root — rarely true after any cd/subshell/
pipeline. Downstream 003-NTB-ATC-Plugin observed 680 silent failures in one session.
That regression is what this file guards, and it still does.
T-2709 (from the T-2704 RCA) — WHY THE ASSERTION CHANGED, and why this file was
rewritten rather than deleted:
The original remediation framed the choice as *relative vs absolute* and pinned the
winner as a test invariant here: every command must `startswith('/')`. But the

## Dependencies (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [init](/docs/generated/lib-init) | calls | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [upgrade](/docs/generated/lib-upgrade) | calls | fw upgrade - Sync framework improvements to a consumer project |
| [hook-config](/docs/generated/hook-config) | reads | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [init](/docs/generated/lib-init) | tests | fw init - Bootstrap a new project with the Agentic Engineering Framework |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-hook_absolute_paths.yaml`*
*Last verified: 2026-04-24*
