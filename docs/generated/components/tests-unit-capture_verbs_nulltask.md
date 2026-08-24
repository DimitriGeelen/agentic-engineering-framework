# capture_verbs_nulltask

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/capture_verbs_nulltask.bats`

## What It Does

T-2878 — the capture verbs must be reachable in the state that completing work creates.
Closing a task nulls focus. The very next things the framework PRESCRIBES — record the
learning, capture the observation, generate the handover — were then refused by the same
Bash gate, with no active task to satisfy it and no way to create one that would be honest.
Third instance of the class: T-2052 (`fw task create`), T-2054 (`git commit`), this.
WHY THE CONTROLS ARE IN THE SAME FILE:
The cheap wrong fix is a blanket `context)` or `fw` allowance, which passes every ALLOWED
leg below and cannot be told apart from the verb-scoped fix by reading them. `fw config set`
(mutating, same `fw` prefix) and `rm -rf` (the outer safe-list boundary) must STILL be gated
— those two legs are the only thing separating this fix from "turn the gate off".

## Dependencies (5)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-capture_verbs_nulltask.yaml`*
*Last verified: 2026-08-08*
