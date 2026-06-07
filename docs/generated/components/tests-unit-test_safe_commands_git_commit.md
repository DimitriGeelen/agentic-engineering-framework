# test_safe_commands_git_commit

> TODO: describe what this component does

**Type:** script | **Subsystem:** unknown | **Location:** `tests/unit/test_safe_commands_git_commit.bats`

## What It Does

T-2054 — post-completion commit deadlock: `git commit` must be allowed when
focus is null, WITHOUT breaking the focus-drift gate (T-1730) when focus exists.
Why the deadlock: `fw task update --status work-completed` nulls focus.yaml AND
moves the task active/→completed/. The completion's own file-move + episodic
must still be committed, but the no-active-task gate blocked git commit — and
the just-completed task can't be re-focused (G-013). Deadlock.
Why NOT a context-free allowlist entry: putting `git commit` in
is_bash_safe_command would short-circuit check-active-task.sh BEFORE the
focus-drift gate, so `git commit -m "T-OTHER:"` under focus=T-CURRENT would
silently bypass T-1730. Instead the null-focus allow lives in

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | tests | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-test_safe_commands_git_commit.yaml`*
*Last verified: 2026-05-25*
