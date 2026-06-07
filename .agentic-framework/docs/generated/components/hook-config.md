# hook-config

> Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns.

**Type:** config | **Subsystem:** enforcement | **Location:** `.claude/settings.json`

**Tags:** `hooks`, `enforcement`, `PreToolUse`, `PostToolUse`, `configuration`

## What It Does

## Dependencies (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | triggers | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools — _PreToolUse hook on Write\|Edit_ |
| [check-tier0](/docs/generated/agents-context-check-tier0) | triggers | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool — _PreToolUse hook on Bash_ |
| [budget-gate](/docs/generated/budget-gate) | triggers | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. — _PreToolUse hook on Write\|Edit\|Bash (budget-gate.sh)_ |
| [checkpoint](/docs/generated/checkpoint) | triggers | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. — _PostToolUse hook on all tools (checkpoint.sh)_ |
| [error-watchdog](/docs/generated/agents-context-error-watchdog) | triggers | Error Watchdog — PostToolUse hook for Bash error detection — _PostToolUse hook on Bash_ |
| [check-dispatch](/docs/generated/agents-context-check-dispatch) | triggers | Dispatch Guard — PostToolUse hook for Task/TaskOutput result size. Warns when sub-agent results exceed safe thresholds (G-008 enforcement). — _PostToolUse hook on Task\|TaskOutput_ |
| [pre-compact](/docs/generated/agents-context-pre-compact) | triggers | Pre-Compaction Hook — Save structured context before lossy compaction — _PreCompact lifecycle hook_ |
| [post-compact-resume](/docs/generated/agents-context-post-compact-resume) | triggers | Session Resume Hook — Reinject structured context on session recovery — _SessionStart lifecycle hook (compact, resume)_ |

## Used By (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [enforcement](/docs/generated/web-blueprints-enforcement) | called_by | Flask blueprint: Enforcement |

---
*Auto-generated from Component Fabric. Card: `hook-config.yaml`*
*Last verified: 2026-02-20*
