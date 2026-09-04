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

## Dependencies (4)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [safe-commands](/docs/generated/agents-context-lib-safe-commands) | calls | Allowlist of safe bash commands for task gate bypass — git status, ls, cat, grep etc. that dont need an active task. |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [config](/docs/generated/lib-config) | calls | Resolves framework configuration values using 3-tier precedence — explicit argument, FW_* environment variable, then hardcoded default |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |

## Used By (50)

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
| [test_safe_commands_git_commit](/docs/generated/tests-unit-test_safe_commands_git_commit) | called_by | TODO: describe what this component does |
| [test_safe_commands_git_commit](/docs/generated/tests-unit-test_safe_commands_git_commit) | tests_by | TODO: describe what this component does |
| [check_active_task_cwd_resolution](/docs/generated/tests-unit-check_active_task_cwd_resolution) | called_by | TODO: describe what this component does |
| [check_active_task_cwd_resolution](/docs/generated/tests-unit-check_active_task_cwd_resolution) | tests_by | TODO: describe what this component does |
| [hook-config](/docs/generated/hook-config) | called_by | Claude Code hook wiring. Defines which scripts run on PreToolUse and PostToolUse events, with matcher patterns. |
| [hook_enable_absolute_path](/docs/generated/tests-unit-hook_enable_absolute_path) | called_by | TODO: describe what this component does |
| [hook_parity](/docs/generated/lib-hook_parity) | called_by | TODO: describe what this component does |
| [prescribed-commands-are-allowed](/docs/generated/tests-lint-prescribed-commands-are-allowed) | tests_by | TODO: describe what this component does |
| [capture_verbs_nulltask](/docs/generated/tests-unit-capture_verbs_nulltask) | called_by | TODO: describe what this component does |
| [capture_verbs_nulltask](/docs/generated/tests-unit-capture_verbs_nulltask) | tests_by | TODO: describe what this component does |
| [drift_gate_not_shadowed_by_safelist](/docs/generated/tests-unit-drift_gate_not_shadowed_by_safelist) | called_by | TODO: describe what this component does |
| [drift_gate_not_shadowed_by_safelist](/docs/generated/tests-unit-drift_gate_not_shadowed_by_safelist) | tests_by | TODO: describe what this component does |
| [hook_absolute_paths](/docs/generated/tests-unit-hook_absolute_paths) | called_by | Regression test — .claude/settings.json hook commands must emit absolute paths (canonicalized via cd && pwd at init/upgrade time), because Claude Code resolves hook commands against the session CWD. Relative paths cascade into tool-blocks when CWD drifts. |
| [onboarding_gate_arc_tag_fp](/docs/generated/tests-unit-onboarding_gate_arc_tag_fp) | called_by | TODO: describe what this component does |
| [onboarding_gate_arc_tag_fp](/docs/generated/tests-unit-onboarding_gate_arc_tag_fp) | tests_by | TODO: describe what this component does |
| [settings_regenerate_preserves_hooks](/docs/generated/tests-unit-settings_regenerate_preserves_hooks) | called_by | TODO: describe what this component does |
| [t2936_bootstrap_quoted_redirect](/docs/generated/tests-unit-t2936_bootstrap_quoted_redirect) | called_by | TODO: describe what this component does |
| [t2936_bootstrap_quoted_redirect](/docs/generated/tests-unit-t2936_bootstrap_quoted_redirect) | tests_by | TODO: describe what this component does |
| [t2987_bootstrap_shape_hint](/docs/generated/tests-unit-t2987_bootstrap_shape_hint) | called_by | TODO: describe what this component does |
| [t2987_bootstrap_shape_hint](/docs/generated/tests-unit-t2987_bootstrap_shape_hint) | tests_by | TODO: describe what this component does |
| [t2988_grouped_command_classification](/docs/generated/tests-unit-t2988_grouped_command_classification) | called_by | TODO: describe what this component does |
| [t2988_grouped_command_classification](/docs/generated/tests-unit-t2988_grouped_command_classification) | tests_by | TODO: describe what this component does |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | called_by | TODO: describe what this component does |
| [t3038_session_scoped_focus](/docs/generated/tests-unit-t3038_session_scoped_focus) | tests_by | TODO: describe what this component does |
| [t3050_b005_block_message](/docs/generated/tests-unit-t3050_b005_block_message) | called_by | TODO: describe what this component does |
| [t3050_b005_block_message](/docs/generated/tests-unit-t3050_b005_block_message) | tests_by | TODO: describe what this component does |
| [t3112_worktree_hook_parity](/docs/generated/tests-unit-t3112_worktree_hook_parity) | called_by | TODO: describe what this component does |
| [t3113_upgrade_worktree_advisory](/docs/generated/tests-unit-t3113_upgrade_worktree_advisory) | called_by | TODO: describe what this component does |
| [check-onboarding-gate](/docs/generated/agents-context-check-onboarding-gate) | read_by | T-2815 PreToolUse Write/Edit hook — refuses adding an agent-unresolvable task (owner != human but agent-unresolvable: inception workflow_type or an unticked ### Human AC) to the T-532 gated onboarding set. Bash wrapper exec's the real logic in check-onboarding-gate.py. |
| [t3174_partial_complete_edit_matrix](/docs/generated/tests-unit-t3174_partial_complete_edit_matrix) | tests_by | TODO: describe what this component does |
| [t3179_partial_complete_commit](/docs/generated/tests-unit-t3179_partial_complete_commit) | tests_by | TODO: describe what this component does |
| [t3221_commit_exemption_clause](/docs/generated/tests-unit-t3221_commit_exemption_clause) | tests_by | Pins the commit-checkpoint exemption in the Bash task gate. Both exemption branches (T-2054 null-focus, T-3179 partial-complete) once admitted any command whose raw text CONTAINED "git commit" — so a trailing `; rm -rf` rode through, a `\| tee` write the gate had already flagged was admitted anyway, and an unknown binary passed because a quoted argument said the words. This suite probes the SHIPPED hook through its real stdin JSON contract rather than re-implementing the predicate, and carries two controls that decide whether a green run means anything: a mutation control that rebuilds the pre-fix hook from live source (so reverting the fix reddens the suite), and a 16-command no-widening sweep asserting the fixed hook admits nothing the pre-fix one blocked. |
| [t3222_fetch_writes_file](/docs/generated/tests-unit-t3222_fetch_writes_file) | tests_by | Pins that curl and wget are admitted by the Bash safe-list only when they do not write a file. Both sat in the list unconditionally, so `curl -o FILE` and `wget -O FILE` — which write with no shell redirect, and are therefore invisible to has_bash_write_pattern — ran with no active task. Covers 22 spellings in both directions, including the stdout forms (`-o -`, `-O -`) that must stay safe and the framework's own documented verification idiom `curl -sf "$(bin/fw watchtower url)/page"`. Two legs carry the design decision: one asserts a commit whose MESSAGE mentions `curl -o` is still admitted (why the check is clause-scoped rather than in the whole-string write scanner), and one asserts a commit chained to a fetch-write is now refused with no change to the T-3221 commit predicate. Mutation control restores the unconditional arm from live source; a no-widening sweep asserts the fix admits nothing the pre-fix version blocked. |
| [t3231_help_exemption_scope](/docs/generated/tests-unit-t3231_help_exemption_scope) | tests_by | TODO: describe what this component does |
| [t3245_trailer_quote_strip](/docs/generated/tests-unit-t3245_trailer_quote_strip) | tests_by | TODO: describe what this component does |
| [t3221_commit_exemption_clause](/docs/generated/tests-unit-t3221_commit_exemption_clause) | called_by | Pins the commit-checkpoint exemption in the Bash task gate. Both exemption branches (T-2054 null-focus, T-3179 partial-complete) once admitted any command whose raw text CONTAINED "git commit" — so a trailing `; rm -rf` rode through, a `\| tee` write the gate had already flagged was admitted anyway, and an unknown binary passed because a quoted argument said the words. This suite probes the SHIPPED hook through its real stdin JSON contract rather than re-implementing the predicate, and carries two controls that decide whether a green run means anything: a mutation control that rebuilds the pre-fix hook from live source (so reverting the fix reddens the suite), and a 16-command no-widening sweep asserting the fixed hook admits nothing the pre-fix one blocked. |
| [t3222_fetch_writes_file](/docs/generated/tests-unit-t3222_fetch_writes_file) | called_by | Pins that curl and wget are admitted by the Bash safe-list only when they do not write a file. Both sat in the list unconditionally, so `curl -o FILE` and `wget -O FILE` — which write with no shell redirect, and are therefore invisible to has_bash_write_pattern — ran with no active task. Covers 22 spellings in both directions, including the stdout forms (`-o -`, `-O -`) that must stay safe and the framework's own documented verification idiom `curl -sf "$(bin/fw watchtower url)/page"`. Two legs carry the design decision: one asserts a commit whose MESSAGE mentions `curl -o` is still admitted (why the check is clause-scoped rather than in the whole-string write scanner), and one asserts a commit chained to a fetch-write is now refused with no change to the T-3221 commit predicate. Mutation control restores the unconditional arm from live source; a no-widening sweep asserts the fix admits nothing the pre-fix version blocked. |
| [check-human-ac-tick](/docs/generated/agents-context-check-human-ac-tick-py) | called_by | TODO: describe what this component does |

## Documentation

- [Deep Dive: The Task Gate](docs/articles/deep-dives/01-task-gate.md) (deep-dive)

## Related

### Tasks
- T-821: Hook crash distinguishability — trap handlers + stderr headers for crash vs block

---
*Auto-generated from Component Fabric. Card: `agents-context-check-active-task.yaml`*
*Last verified: 2026-03-01*
