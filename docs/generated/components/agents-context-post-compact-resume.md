# post-compact-resume

> Session Resume Hook — Reinject structured context on session recovery

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/post-compact-resume.sh`

## What It Does

Session Resume Hook — Reinject structured context on session recovery
Fires on SessionStart with matchers "compact" and "resume" (T-188).
Outputs additionalContext JSON so Claude has framework state immediately.
Triggers:
- After /compact (manual compaction recovery)
- After claude -c (session continuation, including auto-restart via T-179)
Part of: T-111 (compact-resume), T-179/T-188 (auto-restart)

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fabric](/docs/generated/agents-fabric-fabric) | calls | Fabric Agent - Component topology system for codebase self-awareness |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [doctor-hook-exercise](/docs/generated/lib-doctor-hook-exercise) | calls | T-1629 (B-3a of T-1626) & T-070 — `fw doctor` active hook probe. |
| [inject-next-directive](/docs/generated/agents-context-inject-next-directive) | calls | T-2364/T-2365 (T-2158 S2+S3) — next-directive injector for post-compact resume. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (9)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook-config](/docs/generated/hook-config) | used-by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [session_start_hook_warning](/docs/generated/tests-unit-session_start_hook_warning) | called_by | T-1630 (B-4 of T-1626) — SessionStart resume hook warns on broken hooks. |
| [session_start_hook_warning](/docs/generated/tests-unit-session_start_hook_warning) | tests_by | T-1630 (B-4 of T-1626) — SessionStart resume hook warns on broken hooks. |
| [continuous_loop](/docs/generated/tests-integration-continuous_loop) | called_by | T-2368 (arc-012 S-test): end-to-end continuous-loop integration test. |
| [continuous_loop](/docs/generated/tests-integration-continuous_loop) | tests_by | T-2368 (arc-012 S-test): end-to-end continuous-loop integration test. |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [t3431_fabric_session_start](/docs/generated/tests-unit-t3431_fabric_session_start) | tests_by | T-3431 (D-592): SessionStart hook (post-compact-resume.sh) runs a bounded `fw fabric enrich --describe --quiet` on every start/resume/compact and injects one summary line; `fw resume status` mirrors the cached line rather than re-running… |

---
*Auto-generated from Component Fabric. Card: `agents-context-post-compact-resume.yaml`*
*Last verified: 2026-02-20*
