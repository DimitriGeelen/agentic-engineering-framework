# check_active_task_switch_focus

> Pins the focus-drift bypass mechanism contract introduced by T-1730 and
fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under
CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two
bypass mechanisms exist:
  (a) --switch-focus flag — for fw commands whose downstream parsers
      (update-task.sh, lib/{learning,pattern,decision}.sh) consume it
      as a no-op token.
  (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git
      commit ... T-X: ...` where git rejects unknown flags.

Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown
option: --switch-focus" from update-task.sh; agent worked around via
direct-invoke `bash agents/task-create/update-task.sh` which the hook
regex doesn't match → silent bypass, no audit trail. Producer/consumer
split: hook shipped the contract; consumers never honoured it.

9 tests: block-without-bypass, --switch-focus flag allow+log,
FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case,
block-message names both mechanisms, four downstream consumers each
accept --switch-focus without Unknown-option exit.


**Type:** script | **Subsystem:** testing | **Location:** `tests/unit/check_active_task_switch_focus.bats`

**Tags:** `test`, `bats`, `focus-drift`, `hook`, `bypass-contract`, `T-1890`, `T-1730`, `T-1729`

## What It Does

T-1890: focus-drift bypass mechanism contract.
The check-active-task.sh PreToolUse hook (T-1730) detects when a Bash
command targets a task ≠ the focused task and blocks under agent control.
Two bypass mechanisms exist:
(a) --switch-focus flag in the command (for fw commands whose downstream
parsers consume the no-op token);
(b) FW_SWITCH_FOCUS=1 env-var prefix (universal — works for git commit
and any external tool that rejects unknown flags).
This test pins the contract end-to-end: the hook recognises both
mechanisms, logs each with its own `flag:` field, and the downstream

## Dependencies (12)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [check-active-task](/docs/generated/agents-context-check-active-task) | calls | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [update-task](/docs/generated/agents-task-create-update-task) | calls | Task Update Agent - Status transitions with auto-triggers |
| [add-learning](/docs/generated/add-learning) | calls | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [pattern](/docs/generated/agents-context-lib-pattern) | calls | Context Agent - add-pattern command |
| [decision](/docs/generated/agents-context-lib-decision) | calls | Context Agent - add-decision command |
| [update-task](/docs/generated/agents-task-create-update-task) | tests | Task Update Agent - Status transitions with auto-triggers |
| [pattern](/docs/generated/agents-context-lib-pattern) | tests | Context Agent - add-pattern command |
| [decision](/docs/generated/agents-context-lib-decision) | tests | Context Agent - add-decision command |
| [check-active-task](/docs/generated/agents-context-check-active-task) | tests | Task-First Enforcement Hook — PreToolUse gate for Write/Edit tools |
| [fw](/docs/generated/bin-fw) | tests | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [add-learning](/docs/generated/add-learning) | calls | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |
| [add-learning](/docs/generated/add-learning) | tests | Add a learning entry to project memory (learnings.yaml). Assigns next L-XXX ID, formats YAML, inserts before candidates section. |

---
*Auto-generated from Component Fabric. Card: `tests-unit-check_active_task_switch_focus.yaml`*
*Last verified: 2026-05-18*
