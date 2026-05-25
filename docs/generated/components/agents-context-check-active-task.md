# check-active-task

> Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/check-active-task.sh`

## What It Does

Task-First Enforcement Hook — PreToolUse gate for Write/Edit/Bash tools
Blocks file modifications when no active task is set in focus.yaml.
Exit codes (Claude Code PreToolUse semantics):
0 — Allow tool execution
2 — Block tool execution (stderr shown to agent)
Receives JSON on stdin with tool_name and tool_input.
For Write/Edit: checks tool_input.file_path
For Bash: checks tool_input.command against safe-command allowlist (T-650)
Exempt paths (framework operations that don't need task context):
.context/   — Context fabric management

## Dependencies (3)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |

## Used By (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [hook-config](/docs/generated/hook-config) | triggered_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. — _PreToolUse hook on Write\|Edit (.claude/settings.json)_ |
| [self-audit](/docs/generated/agents-audit-self-audit) | verified_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. — _self-audit checks existence and executable bit_ |
| [test-onboarding](/docs/generated/agents-onboarding-test-test-onboarding) | called_by | End-to-end onboarding flow test with 8 checkpoints: scaffold, hooks, first task, task gate, first commit, audit, self-audit, handover. Validates that fw init produces a working project. |
| [self-audit](/docs/generated/agents-audit-self-audit) | read_by | Standalone framework integrity check (Layers 1-4) that does not depend on fw CLI. Verifies foundation files, directory structure, Claude Code hooks, and git hooks. |
| [check-project-boundary](/docs/generated/agents-context-check-project-boundary) | related_by | PreToolUse hook that blocks Write/Edit/Bash operations targeting paths outside PROJECT_ROOT. Prevents cross-project edits. Part of the project boundary enforcement gate (T-559). |
| [hook-config](/docs/generated/hook-config) | triggers_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook-config](/docs/generated/hook-config) | used-by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [focus_drift_gate](/docs/generated/tests-unit-focus_drift_gate) | called_by | TODO: describe what this component does |
| [focus_drift_gate](/docs/generated/tests-unit-focus_drift_gate) | tests_by | TODO: describe what this component does |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | called_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-active-task.yaml`*
*Last verified: 2026-03-01*
