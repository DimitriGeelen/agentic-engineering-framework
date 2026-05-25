# self-audit

> Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks.

**Type:** script | **Subsystem:** audit | **Location:** `agents/audit/self-audit.sh`

**Tags:** `audit`, `standalone`, `integrity`

## What It Does

Self-Audit — Standalone Framework Integrity Check
Verifies Layers 1-4 of the Agentic Engineering Framework
without depending on fw CLI (solves chicken-and-egg problem).
Usage:
agents/audit/self-audit.sh                 # Run from framework root
agents/audit/self-audit.sh /path/to/project # Audit a specific project
agents/audit/self-audit.sh --quiet          # Machine-readable (no color)
Exit codes: 0=pass, 1=warnings, 2=failures

## Dependencies (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | reads | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. — _Checks existence and executable bit (Layer 1)_ |
| [hook-config](/docs/generated/hook-config) | reads | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. — _Reads and parses .claude/settings.json to verify hook wiring (Layer 3)_ |
| [check-active-task](/docs/generated/agents-context-check-active-task) | reads | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools — _Verifies hook script exists, is executable, and parses (Layer 1)_ |
| [check-tier0](/docs/generated/agents-context-check-tier0) | reads | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool — _Verifies hook script exists, is executable, and parses (Layer 1)_ |
| [budget-gate](/docs/generated/budget-gate) | reads | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. — _Verifies budget-gate.sh exists, is executable, and parses (Layer 1)_ |
| [checkpoint](/docs/generated/checkpoint) | reads | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. — _Verifies checkpoint.sh exists, is executable, and parses (Layer 1)_ |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | reads | Error Watchdog — PostToolUse hook for Bash error detection — _Verifies hook script exists, is executable, and parses (Layer 1)_ |
| [check-dispatch](/docs/generated/agents-context-check-dispatch) | reads | Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). — _Verifies hook script exists, is executable, and parses (Layer 1)_ |
| [pre-compact](/docs/generated/agents-context-pre-compact) | reads | Pre-Compaction Hook — Save structured context before lossy compaction — _Verifies hook script exists, is executable, and parses (Layer 1)_ |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | reads | Session Resume Hook — Reinject structured context on session recovery — _Verifies hook script exists, is executable, and parses (Layer 1)_ |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |

## Used By (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Related

### Tasks
- T-796: Fix remaining single-warning shellcheck issues in agent scripts
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-audit-self-audit.yaml`*
*Last verified: 2026-03-01*
