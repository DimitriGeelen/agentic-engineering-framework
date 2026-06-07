# test_pretooluse_gates

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/governance/test_pretooluse_gates.bats`

## What It Does

T-1606 (T-1601 GO follow-up): red-team harness covering all 7 PreToolUse gates.
Pattern: invoke each PreToolUse hook directly with a constructed JSON envelope
matching Claude Code's tool-call format, assert exit code 2 (block) and that
stderr contains the expected error keyword.
Renames + extends tests/governance/test_gates_prototype.bats (3 gates) to cover:
1. block-plan-mode        (EnterPlanMode)
2. block-task-tools       (TodoWrite/TaskCreate/TaskUpdate/TaskList/TaskGet)
3. check-active-task      (Write/Edit without focus)
4. check-tier0            (Bash with destructive command, no approval)
5. check-agent-dispatch   (Agent tool exceeding FW_DISPATCH_LIMIT)

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-governance-test_pretooluse_gates.yaml`*
*Last verified: 2026-04-29*
