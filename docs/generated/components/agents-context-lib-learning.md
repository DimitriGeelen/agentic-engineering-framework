# learning

> Context Agent - add-learning command Add a learning to project memory

**Type:** script | **Subsystem:** context-fabric | **Location:** `agents/context/lib/learning.sh`

## What It Does

Context Agent - add-learning command
Add a learning to project memory

### Framework Reference

When fixing a bug discovered through real-world usage (user testing, production incident, cross-platform failure):
1. **Classify the bug** — Is this a new failure class, or a repeat of a known pattern?
2. **Check learnings.yaml** — Does a learning already exist for this class?
3. If new class: `fw context add-learning "description" --task T-XXX --source P-001`
4. If systemic (same class hit 2+ times): register in `concerns.yaml`, consider tooling fix (Level C/D)

*(truncated — see CLAUDE.md for full section)*

## Dependencies (1)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [corpus-id](/docs/generated/lib-corpus-id) | calls | lib/corpus-id.sh — serialisation-independent max-id lookup for the YAML memory corpus |

## Used By (8)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | called_by | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [context_learning](/docs/generated/tests-unit-context_learning) | tests_by | Unit tests for context learning (10 tests) |
| [corpus_id_allocator](/docs/generated/tests-unit-corpus_id_allocator) | tests_by | T-2902 — the L-/PL- allocator must not reissue a live id when the corpus changes shape. |
| [learning_application_birth](/docs/generated/tests-unit-learning_application_birth) | tests_by | T-2901: `application:` must not be born populated. |
| [t1719_post_write_index](/docs/generated/tests-unit-t1719_post_write_index) | tests_by | T-1719 A1 — the post-write index hook, and the boundary of where it may be wired. |
| [add_learning_id_allocator](/docs/generated/tests-unit-add_learning_id_allocator) | called_by | Regression test — add-learning ID allocator handles BOTH legacy indented format ('  id: L-XXX') and new dash-prefix format ('- id: L-XXX'). Pre-fix grep for '^- id: L-' missed 234 legacy entries, causing new IDs to collide with historical ones. |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | called_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |

---
*Auto-generated from Component Fabric. Card: `agents-context-lib-learning.yaml`*
*Last verified: 2026-09-05*
