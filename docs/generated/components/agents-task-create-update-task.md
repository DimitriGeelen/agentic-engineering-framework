# update-task

> Task Update Agent - Status transitions with auto-triggers

**Type:** script | **Subsystem:** task-management | **Location:** `agents/task-create/update-task.sh`

## What It Does

Task Update Agent - Status transitions with auto-triggers
Updates task frontmatter and triggers structural actions:
issues/blocked  → auto-diagnose via healing agent
work-completed  → set date_finished, move to completed/, generate episodic
Usage:
./agents/task-create/update-task.sh T-XXX --status issues
./agents/task-create/update-task.sh T-XXX --status work-completed
./agents/task-create/update-task.sh T-XXX --owner claude-code
./agents/task-create/update-task.sh T-XXX --status blocked --reason "Waiting on API key"

## Dependencies (14)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [enums](/docs/generated/lib-enums) | calls | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [keylock](/docs/generated/lib-keylock) | calls | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [evolution_log](/docs/generated/lib-evolution_log) | calls | TODO: describe what this component does |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | calls | TODO: describe what this component does |
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | calls | TODO: describe what this component does |
| [task_pair_acd-py](/docs/generated/lib-task_pair_acd-py) | calls | Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO). |
| [render_surface](/docs/generated/lib-render_surface) | calls | TODO: describe what this component does |
| [bvp-estimator](/docs/generated/agents-termlink-bvp-estimator-bvp-estimator) | calls | TODO: describe what this component does |
| [inception_decisions](/docs/generated/lib-inception_decisions) | calls | TODO: describe what this component does |

## Used By (27)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called-by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [update_task](/docs/generated/tests-unit-update_task) | tested_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [update_task](/docs/generated/tests-unit-update_task) | called_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [T-1067-horizon-status-invariants](/docs/generated/docs-reports-T-1067-horizon-status-invariants) | references_by | Research report: horizon/status invariant rules. Defines the consistency rules enforced by update-task.sh (T-1068). |
| [update_task_episodic_gen](/docs/generated/tests-unit-update_task_episodic_gen) | called_by | Regression test — episodic auto-gen on status: work-completed. Four tasks in one session (T-1363/1364/1366/1367) transitioned to work-completed (date_finished set, [task-update-agent] Updates entry) yet no episodic was generated. Pins the happy path so any regression surfaces. |
| [arc](/docs/generated/lib-arc) | called_by | TODO: describe what this component does |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | TODO: describe what this component does |
| [skip_ac_partial_complete](/docs/generated/tests-unit-skip_ac_partial_complete) | called_by | TODO: describe what this component does |
| [skip_ac_partial_complete](/docs/generated/tests-unit-skip_ac_partial_complete) | tests_by | TODO: describe what this component does |
| [update_task](/docs/generated/tests-unit-update_task) | tests_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [update_task_episodic_gen](/docs/generated/tests-unit-update_task_episodic_gen) | tests_by | Regression test — episodic auto-gen on status: work-completed. Four tasks in one session (T-1363/1364/1366/1367) transitioned to work-completed (date_finished set, [task-update-agent] Updates entry) yet no episodic was generated. Pins the happy path so any regression surfaces. |
| [update_task_yaml_components_emit](/docs/generated/tests-unit-update_task_yaml_components_emit) | called_by | TODO: describe what this component does |
| [update_task_yaml_components_emit](/docs/generated/tests-unit-update_task_yaml_components_emit) | tests_by | TODO: describe what this component does |
| [test_task_pair_acd_gate](/docs/generated/tests-unit-test_task_pair_acd_gate) | called_by | TODO: describe what this component does |
| [test_task_pair_acd_gate](/docs/generated/tests-unit-test_task_pair_acd_gate) | tests_by | TODO: describe what this component does |
| [arc_membership_agent_surfaces](/docs/generated/tests-unit-arc_membership_agent_surfaces) | tests_by | TODO: describe what this component does |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | called_by | TODO: describe what this component does |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | TODO: describe what this component does |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | called_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [check_render_surface_human_ac_sigpipe](/docs/generated/tests-unit-check_render_surface_human_ac_sigpipe) | tests_by | TODO: describe what this component does |
| [update_task_horizon_null_on_close](/docs/generated/tests-unit-update_task_horizon_null_on_close) | called_by | TODO: describe what this component does |
| [update_task_horizon_null_on_close](/docs/generated/tests-unit-update_task_horizon_null_on_close) | tests_by | TODO: describe what this component does |
| [disposition_gate](/docs/generated/tests-unit-disposition_gate) | called_by | TODO: describe what this component does |
| [disposition_gate](/docs/generated/tests-unit-disposition_gate) | tests_by | TODO: describe what this component does |

## Documentation

- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-795: Fix shellcheck warnings across agent scripts — SC2155, SC2144, SC2034, SC2044
- T-797: Shellcheck cleanup: audit.sh and remaining framework scripts
- T-848: Sync vendored .agentic-framework/ with all recent fixes

---
*Auto-generated from Component Fabric. Card: `agents-task-create-update-task.yaml`*
*Last verified: 2026-02-20*
