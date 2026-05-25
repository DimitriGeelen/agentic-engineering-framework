# decision

> Context Agent - add-decision command

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/decision.sh`

## What It Does

Context Agent - add-decision command
Add a decision to project memory

## Used By (6)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context-dispatcher](/docs/generated/context-dispatcher) | called-by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [context_decision](/docs/generated/tests-unit-context_decision) | called_by | Unit tests for context decision (11 tests) |
| [context_decision](/docs/generated/tests-unit-context_decision) | tests_by | Unit tests for context decision (11 tests) |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | called_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |

## Documentation

- [Deep Dive: Three-Layer Memory](docs/articles/deep-dives/04-three-layer-memory.md) (deep-dive)

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-decision.yaml`*
*Last verified: 2026-02-20*
