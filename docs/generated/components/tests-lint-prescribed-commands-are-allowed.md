# prescribed-commands-are-allowed

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/lint/prescribed-commands-are-allowed.bats`

## What It Does

T-2702 — a command one gate PRESCRIBES must be one the budget gate ALLOWS.
Origin: check-active-task.sh blocks when focus is empty (the state a
just-completed task leaves behind) and prints `fw context focus T-XXX` as the
remedy. budget-gate.sh's allowed-command allowlist carried `context init` but
not `context focus`, so at critical budget the agent was told the remedy and
denied it in the same breath — a hard deadlock at exactly the moment the
session is trying to wrap up.
Reported by a consumer (832) who hit it and could NOT file it, because filing
required the blocked path. A defect that suppresses its own bug report will not
arrive through the usual channel, so it needs a standing check rather than a

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [cmd_classify](/docs/generated/lib-cmd_classify) | tests | TODO: describe what this component does |
| [budget-gate](/docs/generated/budget-gate) | tests | Block Write/Edit/Bash tool execution when context budget reaches critical level (>=170K tokens). Primary enforcement for P-009. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |

---
*Auto-generated from Component Fabric. Card: `tests-lint-prescribed-commands-are-allowed.yaml`*
*Last verified: 2026-07-31*
