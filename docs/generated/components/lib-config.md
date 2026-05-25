# config

> Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default

**Type:** script | **Subsystem:** framework-core | **Location:** `lib/config.sh`

## What It Does

lib/config.sh — 3-tier configuration resolution
Pattern: explicit arg > FW_* env var > hardcoded default
Usage:
source "$FRAMEWORK_ROOT/lib/config.sh"
CONTEXT_WINDOW=$(fw_config "CONTEXT_WINDOW" 300000)
DISPATCH_LIMIT=$(fw_config_int "DISPATCH_LIMIT" 2)
Origin: T-817 inception (traceAI pattern adoption), T-819 build

### Framework Reference

4-tier resolution: explicit CLI flag > `FW_*` env var > `.framework.yaml` > hardcoded default. Persistent per-project config: `fw config set KEY VALUE` writes to `.framework.yaml`.

Agent-relevant settings:
- `FW_CONTEXT_WINDOW` (300000) — budget enforcement ceiling
- `FW_PORT` (3000) — Watchtower listen port (also resolved via triple-file; see Watchtower Port section)
- `FW_SAFE_MODE` (0) — bypass task gate (escape hatch)
- `FW_DISPATCH_LIMIT` (2) — Agent tool cap before TermLink gate
- `FW_STALE_ARC_DAYS` (30) — T-1855: stale-arc audit WARN threshold. In-progress arcs whose constituent tasks

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (27)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [verify-acs](/docs/generated/lib-verify-acs) | called-by | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [lib_config](/docs/generated/tests-unit-lib_config) | called-by | TODO: describe what this component does |
| [config](/docs/generated/web-templates-config) | used-by | Watchtower /config page — show all FW_* settings with current values and sources |
| [config](/docs/generated/lib-config) | called-by | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [check-active-task](/docs/generated/agents-context-check-active-task) | called_by | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [check-agent-dispatch](/docs/generated/agents-context-check-agent-dispatch) | called_by | Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed. |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | called_by | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [check-tier0](/docs/generated/agents-context-check-tier0) | called_by | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [pre-compact](/docs/generated/agents-context-pre-compact) | called_by | Pre-Compaction Hook — Save structured context before lossy compaction |
| [termlink](/docs/generated/agents-termlink-termlink) | called_by | TermLink integration wrapper: spawn, exec, dispatch, cleanup, status. Adds task-tagging and budget checks around the termlink binary. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [watchtower](/docs/generated/bin-watchtower) | called_by | Launcher script for Watchtower web dashboard. Starts Flask app on configured port with optional debug mode. |
| [budget-gate](/docs/generated/budget-gate) | called_by | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [checkpoint](/docs/generated/checkpoint) | called_by | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [keylock](/docs/generated/lib-keylock) | called_by | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |
| [config](/docs/generated/lib-config) | called_by | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [verify-acs](/docs/generated/lib-verify-acs) | called_by | Scans work-completed tasks with unchecked Human ACs and runs automated evidence collection where programmatic verification is possible |
| [lib_config](/docs/generated/tests-unit-lib_config) | called_by | TODO: describe what this component does |
| [config](/docs/generated/web-templates-config) | read_by | Watchtower /config page — show all FW_* settings with current values and sources |
| [hooks](/docs/generated/agents-git-lib-hooks) | called_by | Git Agent - Hook installation subcommand |
| [liveness-check](/docs/generated/agents-monitor-liveness-check) | called_by | TODO: describe what this component does |
| [fabric](/docs/generated/tests-unit-fabric) | tests_by | Unit tests for agents/fabric/fabric.sh (10 tests) |
| [lib_config](/docs/generated/tests-unit-lib_config) | tests_by | TODO: describe what this component does |
| [yaml_pipefail](/docs/generated/tests-unit-yaml_pipefail) | called_by | TODO: describe what this component does |
| [yaml_pipefail](/docs/generated/tests-unit-yaml_pipefail) | tests_by | TODO: describe what this component does |
| [config](/docs/generated/web-blueprints-config) | called_by | Flask blueprint that renders the configuration settings page showing all framework settings with current values and resolution sources |

## Related

### Tasks
- T-838: ShellCheck sweep — fix warnings across framework bash scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes
- T-891: Add .framework.yaml as persistent tier in fw_config resolution
- T-892: Fix fw_config_registry — missing .framework.yaml tier lookup
- T-899: Fix shellcheck SC2015 in lib/config.sh fw_config_registry

---
*Auto-generated from Component Fabric. Card: `lib-config.yaml`*
*Last verified: 2026-04-03*
