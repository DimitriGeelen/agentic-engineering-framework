# no-bare-fw-in-gate-scripts

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/no-bare-fw-in-gate-scripts.bats`

## What It Does

Invariant: gate scripts must not emit bare 'fw' commands — use _emit_user_command/_fw_cmd
Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007

## Dependencies (11)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [check-tier0](/docs/generated/agents-context-check-tier0) | tests | Tier 0 Enforcement Hook — PreToolUse gate for Bash tool |
| [hooks](/docs/generated/agents-git-lib-hooks) | tests | Git Agent - Hook installation subcommand |
| [handover](/docs/generated/agents-handover-handover) | tests | Handover Agent - Mechanical Operations |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [checkpoint](/docs/generated/checkpoint) | tests | Post-tool budget monitoring. Warns at thresholds, auto-triggers handover at critical, detects compaction, manages inception checkpoints. |
| [budget-gate](/docs/generated/budget-gate) | tests | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [check-agent-dispatch](/docs/generated/agents-context-check-agent-dispatch) | tests | Agent Dispatch Gate — PreToolUse hook for Agent tool. Tracks dispatches per session, blocks 3rd+ unless approved or TermLink not installed. |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | tests | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [init](/docs/generated/agents-context-lib-init) | tests | Context Agent - init command |

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-bare-fw-in-gate-scripts.yaml`*
*Last verified: 2026-04-13*
