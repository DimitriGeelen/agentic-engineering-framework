# no-bare-fw-in-gate-scripts

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/no-bare-fw-in-gate-scripts.bats`

## What It Does

Invariant: gate scripts must not emit bare 'fw' COMMANDS — use bin/fw, or the
_emit_user_command/_fw_cmd helpers that resolve the right path per project.
Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007.
T-2700 rewrote the detector, which had been red and unrun (T-2697). It flagged
six lines; two were real and four were not, in two distinct ways:
1. `\bfw\b` matches inside `bin/fw`, because `/` is a word boundary. The
guard flagged the exact form it wants. A guard that fires on its own fix
cannot be acted on — the only way to satisfy it was to stop mentioning fw.
2. It could not tell a COMMAND from PROSE ABOUT a command. Lines like
"Works for: fw task update, fw context add-*." are sentences naming verbs,

## Dependencies (12)

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
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-lint-no-bare-fw-in-gate-scripts.yaml`*
*Last verified: 2026-04-13*
