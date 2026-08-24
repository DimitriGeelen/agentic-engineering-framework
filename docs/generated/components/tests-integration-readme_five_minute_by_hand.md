# readme_five_minute_by_hand

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/integration/readme_five_minute_by_hand.bats`

## What It Does

T-2719 (arc-016) — the README's five-minute walkthrough, run as the BY-HAND
persona: a person at a terminal with no AI agent attached.
WHY A SEPARATE PERSONA. The framework's headline property is "nothing gets
done without a task", and it is enforced by TWO different mechanisms with
different reach:
Write/Edit/Bash gate  -> .claude/settings.json PreToolUse hook
fires ONLY for an AI agent's tool calls
commit-msg gate       -> .git/hooks/commit-msg
fires for ANYONE who runs git commit
An agent-assisted walkthrough exercises both and passes. A person exercises

## Dependencies (2)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [create-task](/docs/generated/agents-task-create-create-task) | tests | Task Creation Agent - Mechanical Operations |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

---
*Auto-generated from Component Fabric. Card: `tests-integration-readme_five_minute_by_hand.yaml`*
*Last verified: 2026-08-05*
