# t3231_help_exemption_scope

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/t3231_help_exemption_scope.bats`

## What It Does

T-3231 — the `--help` exemption must not skip every gate.
Finding C2 of the arc-012 review. check-active-task.sh took an unconditional
`exit 0` ahead of every gate whenever `--help` matched ANYWHERE in the command,
including inside a quoted argument. Appending seven characters opted any command
out of governance.
WHY THIS DRIVES THE REAL HOOK rather than re-implementing its predicate: a guard
that reimplements the code it guards cannot detect that code being fixed — or
re-broken (peer 577-CashWeb's G-072 class, and the reason T-3228's suite extracts
the real brake instead of copying it). Here we run the actual script.
WHY THE TEMP PROJECT ROOT: with an active task in focus the gate allows

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-t3231_help_exemption_scope.yaml`*
*Last verified: 2026-08-31*
