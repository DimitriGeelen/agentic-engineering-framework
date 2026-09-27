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

## Dependencies (21)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [context-dispatcher](/docs/generated/context-dispatcher) | calls | Central dispatcher for all context agent commands (init, focus, add-learning, add-pattern, add-decision, status, generate-episodic) |
| [healing](/docs/generated/agents-healing-healing) | calls | Healing Agent - Antifragile error recovery and pattern learning |
| [paths](/docs/generated/lib-paths) | calls | Centralized path resolution for the framework. Sets FRAMEWORK_ROOT, PROJECT_ROOT, TASKS_DIR, CONTEXT_DIR. Replaces the 3-line SCRIPT_DIR/FRAMEWORK_ROOT/PROJECT_ROOT pattern previously duplicated across 25+ agent scripts. Also sources lib/compat.sh for cross-platform helpers. |
| [enums](/docs/generated/lib-enums) | calls | Single source of truth for framework enumerations — valid statuses, workflow types, horizons, and status transitions. Provides is_valid_status(), is_valid_type(), is_valid_horizon(), is_valid_transition() functions. Replaces hardcoded lists previously duplicated across 6+ files. |
| [keylock](/docs/generated/lib-keylock) | calls | Advisory file locking: task-level lock files in .context/locks/ to prevent concurrent task modifications. |
| [review](/docs/generated/lib-review) | calls | fw task review helper: emit Watchtower URL, QR code, and research artifact links for human review presentation. |
| [notify](/docs/generated/lib-notify) | calls | Push notification wrapper — fw_notify() function sends alerts via skills-manager alert dispatcher. Fire-and-forget, opt-in via .context/notify-config.yaml. Used by check-tier0.sh, update-task.sh, audit.sh. |
| [evolution_log](/docs/generated/lib-evolution_log) | calls | Detection helper for the T-1717 Q4 rigidity-vs-evolution pattern (T-1718 implementation). Mirrors lib/inception_recommendation.sh (T-1716) shape exactly: detection helper extracted so it can be tested without spinning up update-task.sh. |
| [static_scan](/docs/generated/lib-reviewer-static_scan) | calls | Static-scan reviewer (T-1443 v1.0 → v1.5). |
| [task_pair_acd](/docs/generated/lib-task_pair_acd) | calls | Task-pair §ACD gate (P-012). G-066 prong 2 — detect substrate-vs- deliverable conflation at work-completed time. Mirror of T-1668/T-1671's arc-level gate at the per-task level. |
| [task_pair_acd-py](/docs/generated/lib-task_pair_acd-py) | calls | Task-pair §ACD gate (P-012, T-1762) — Python core. Parses inception Recommendation->Decomposition headings, verifies promised follow-up build tasks shipped via related_tasks chain. Mirror of T-1668/T-1671 arc-level §ACD gate at task-pair level (G-066 prong 2 implementation per T-1713 GO). |
| [render_surface](/docs/generated/lib-render_surface) | calls | Render-surface predicate (T-1766, P-013). Decides whether a task touches the human-review rendering surface — surfaces where what the human sees depends on layout/CSS/template choices that no deterministic test can fully capture. |
| [bvp-estimator](/docs/generated/agents-termlink-bvp-estimator-bvp-estimator) | calls | TermLink worker entry point for the BVP estimator (T-1922): thin shell wrapper forwarding to estimator.py per the agents/<name>/<name>.sh convention. |
| [inception_decisions](/docs/generated/lib-inception_decisions) | calls | T-1984: inception_decisions / unlocks_inception_decision frontmatter parser. |
| [fw](/docs/generated/bin-fw) | calls | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [verification-port](/docs/generated/lib-verification-port) | calls | lib/verification-port.sh — hard-coded Watchtower port detection (T-2732) |
| [verification-verdict](/docs/generated/lib-verification-verdict) | calls | lib/verification-verdict.sh — unjudged-test-run detection (T-2738) |
| [continuous-mode](/docs/generated/lib-continuous-mode) | calls | Continuous-run counters (T-3169, arc-012 S3). |
| [inception-readiness](/docs/generated/lib-inception-readiness) | calls | lib/inception-readiness.sh — SHARED decision-readiness predicates for inception tasks. |
| [section-extract](/docs/generated/lib-section-extract) | calls | lib/section-extract.sh — anchored section extraction for the task-file sections that gate build/inception completion, other than ## Verification |
| [human_review_state](/docs/generated/lib-human_review_state) | calls | Classifies a task file's '### Human' AC blocks for the P-013 render gate (prints has_review/only_other/empty/no_section/error); single source of truth extracted from update-task.sh (T-3288) |

## Used By (51)

| Component | Relationship | Description |
|-----------|--------------|-------------|
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [fw](/docs/generated/bin-fw) | called_by | Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called-by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [update_task](/docs/generated/tests-unit-update_task) | tested_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [update_task](/docs/generated/tests-unit-update_task) | called_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [T-1067-horizon-status-invariants](/docs/generated/docs-reports-T-1067-horizon-status-invariants) | references_by | Research report: horizon/status invariant rules. Defines the consistency rules enforced by update-task.sh (T-1068). |
| [update_task_episodic_gen](/docs/generated/tests-unit-update_task_episodic_gen) | called_by | Regression test — episodic auto-gen on status: work-completed. Four tasks in one session (T-1363/1364/1366/1367) transitioned to work-completed (date_finished set, [task-update-agent] Updates entry) yet no episodic was generated. Pins the happy path so any regression surfaces. |
| [arc](/docs/generated/lib-arc) | called_by | lib/arc.sh — Arc system (T-1653 Phase 1 / T-1661 / T-1848) |
| [no-bare-fw-in-gate-scripts](/docs/generated/tests-lint-no-bare-fw-in-gate-scripts) | tests_by | Invariant: gate scripts must not emit bare 'fw' COMMANDS — use bin/fw, or the _emit_user_command/_fw_cmd helpers that resolve the right path per project. Origin: T-1146 GO / T-1203 — bare commands are not copy-pasteable and violate PL-007. |
| [skip_ac_partial_complete](/docs/generated/tests-unit-skip_ac_partial_complete) | called_by | T-1559 — Regression: --skip-acceptance-criteria must bypass the AC check on the partial-complete recheck branch, not just the initial transition. |
| [skip_ac_partial_complete](/docs/generated/tests-unit-skip_ac_partial_complete) | tests_by | T-1559 — Regression: --skip-acceptance-criteria must bypass the AC check on the partial-complete recheck branch, not just the initial transition. |
| [update_task](/docs/generated/tests-unit-update_task) | tests_by | Unit tests for agents/task-create/update-task.sh (11 tests) |
| [update_task_episodic_gen](/docs/generated/tests-unit-update_task_episodic_gen) | tests_by | Regression test — episodic auto-gen on status: work-completed. Four tasks in one session (T-1363/1364/1366/1367) transitioned to work-completed (date_finished set, [task-update-agent] Updates entry) yet no episodic was generated. Pins the happy path so any regression surfaces. |
| [update_task_yaml_components_emit](/docs/generated/tests-unit-update_task_yaml_components_emit) | called_by | T-1469: update-task.sh auto-populate components path used a sed line replace that left orphan ` - item` continuation lines from block-style components, producing invalid YAML. |
| [update_task_yaml_components_emit](/docs/generated/tests-unit-update_task_yaml_components_emit) | tests_by | T-1469: update-task.sh auto-populate components path used a sed line replace that left orphan ` - item` continuation lines from block-style components, producing invalid YAML. |
| [test_task_pair_acd_gate](/docs/generated/tests-unit-test_task_pair_acd_gate) | called_by | T-1762: task-pair §ACD gate (P-012) — gate behaviour (T-1713 Spike 3) |
| [test_task_pair_acd_gate](/docs/generated/tests-unit-test_task_pair_acd_gate) | tests_by | T-1762: task-pair §ACD gate (P-012) — gate behaviour (T-1713 Spike 3) |
| [arc_membership_agent_surfaces](/docs/generated/tests-unit-arc_membership_agent_surfaces) | tests_by | T-1879 (T-NEW-14): silent-corpus #2 sweep — agent-side surfaces must read both `arc_id:` frontmatter (T-1849 canonical, T-1850 migrated) AND legacy `arc:<slug>` tag. |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | tests_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | called_by | T-1766 — render-surface Human-AC gate (P-013). |
| [test_render_surface_gate](/docs/generated/tests-unit-test_render_surface_gate) | tests_by | T-1766 — render-surface Human-AC gate (P-013). |
| [check_active_task_switch_focus](/docs/generated/tests-unit-check_active_task_switch_focus) | called_by | Pins the focus-drift bypass mechanism contract introduced by T-1730 and fixed by T-1890. The check-active-task.sh PreToolUse hook blocks under CLAUDECODE=1 when a Bash command targets a task ≠ focused task. Two bypass mechanisms exist:   (a) --switch-focus flag — for fw commands whose downstream parsers       (update-task.sh, lib/{learning,pattern,decision}.sh) consume it       as a no-op token.   (b) FW_SWITCH_FOCUS=1 env-var prefix — universal, works for `git       commit ... T-X: ...` where git rejects unknown flags.  Origin: T-1890 — last-session closures of T-1854/T-1855 hit "Unknown option: --switch-focus" from update-task.sh; agent worked around via direct-invoke `bash agents/task-create/update-task.sh` which the hook regex doesn't match → silent bypass, no audit trail. Producer/consumer split: hook shipped the contract; consumers never honoured it.  9 tests: block-without-bypass, --switch-focus flag allow+log, FW_SWITCH_FOCUS=1 allow+log, FW_SWITCH_FOCUS=1 unlocks git commit case, block-message names both mechanisms, four downstream consumers each accept --switch-focus without Unknown-option exit. |
| [check_render_surface_human_ac_sigpipe](/docs/generated/tests-unit-check_render_surface_human_ac_sigpipe) | tests_by | T-1900: render-surface gate error path used to die with SIGPIPE (exit 141) under set -eo pipefail when `render_surface_files_in \| head -N` produced more lines than head consumed. |
| [update_task_horizon_null_on_close](/docs/generated/tests-unit-update_task_horizon_null_on_close) | called_by | T-2163 / arc-009 Slice 4: write-side horizon-null at full close. |
| [update_task_horizon_null_on_close](/docs/generated/tests-unit-update_task_horizon_null_on_close) | tests_by | T-2163 / arc-009 Slice 4: write-side horizon-null at full close. |
| [disposition_gate](/docs/generated/tests-unit-disposition_gate) | called_by | Unit tests for check_disposition_gate (T-2190). |
| [disposition_gate](/docs/generated/tests-unit-disposition_gate) | tests_by | Unit tests for check_disposition_gate (T-2190). |
| [test_update_task_horizon_null_reclose](/docs/generated/tests-unit-test_update_task_horizon_null_reclose) | called_by | T-2300: re-close-path leg-gap regression test. |
| [test_update_task_horizon_null_reclose](/docs/generated/tests-unit-test_update_task_horizon_null_reclose) | tests_by | T-2300: re-close-path leg-gap regression test. |
| [recommendation_gate_build_partial](/docs/generated/tests-unit-recommendation_gate_build_partial) | called_by | T-2421 (T-2419 GO): Recommendation gate for partial-complete BUILD-class tasks. |
| [recommendation_gate_build_partial](/docs/generated/tests-unit-recommendation_gate_build_partial) | tests_by | T-2421 (T-2419 GO): Recommendation gate for partial-complete BUILD-class tasks. |
| [render_surface_review_state_dup_human](/docs/generated/tests-unit-render_surface_review_state_dup_human) | tests_by | T-1901: render-surface gate's review-state detector reads ALL `### Human` blocks, not just the first. Backward-compatible with single-header tasks. |
| [ac_structure_close_gate](/docs/generated/tests-unit-ac_structure_close_gate) | called_by | T-3029 -- Regression: update-task.sh's close-time AC gate must not silently report zero Human ACs when a `### Human` heading is separated from `## Acceptance Criteria` by an intervening `## ` heading. |
| [ac_structure_close_gate](/docs/generated/tests-unit-ac_structure_close_gate) | tests_by | T-3029 -- Regression: update-task.sh's close-time AC gate must not silently report zero Human ACs when a `### Human` heading is separated from `## Acceptance Criteria` by an intervening `## ` heading. |
| [t2921_verification_comment_strip](/docs/generated/tests-unit-t2921_verification_comment_strip) | called_by | T-2921 — the P-011 verification extractor must strip comments STRUCTURALLY. |
| [t2921_verification_comment_strip](/docs/generated/tests-unit-t2921_verification_comment_strip) | tests_by | T-2921 — the P-011 verification extractor must strip comments STRUCTURALLY. |
| [t2924_update_task_owner_gate](/docs/generated/tests-unit-t2924_update_task_owner_gate) | called_by | T-2924 — `fw task update --owner` must validate against the owner enum. |
| [t2924_update_task_owner_gate](/docs/generated/tests-unit-t2924_update_task_owner_gate) | tests_by | T-2924 — `fw task update --owner` must validate against the owner enum. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | called_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [t2991_verification_preflight](/docs/generated/tests-unit-t2991_verification_preflight) | tests_by | T-2991: P-011 must never eval a line bash cannot parse. |
| [t3030_two_writer_guard](/docs/generated/tests-unit-t3030_two_writer_guard) | tests_by | T-3030 / G-083: the autonomous dispatch loop and an interactive session share one working tree. These tests pin the guard that separates them, and the provenance record that makes a worker's writes attributable afterwards. |
| [update_task_orphan_guard](/docs/generated/tests-unit-update_task_orphan_guard) | called_by | T-1863 — Structural prevention for the active+completed orphan class. Origin: T-1859 was marked work-completed in S-2026-0515-2042 but the active/T-1859 file was never removed from the index, leaving both sides tracked. |
| [update_task_orphan_guard](/docs/generated/tests-unit-update_task_orphan_guard) | tests_by | T-1863 — Structural prevention for the active+completed orphan class. Origin: T-1859 was marked work-completed in S-2026-0515-2042 but the active/T-1859 file was never removed from the index, leaving both sides tracked. |
| [verification_pipe_buffer](/docs/generated/tests-unit-verification_pipe_buffer) | tests_by | T-2743: the capture-then-pipe idiom is SIGPIPE-safe only below the pipe buffer. |
| [t3232_verification_extractor_failure](/docs/generated/tests-unit-t3232_verification_extractor_failure) | tests_by | T-3232 — extraction FAILURE must not read as "this task has no Verification section". |
| [t3235_archived_horizon_invariant](/docs/generated/tests-unit-t3235_archived_horizon_invariant) | tests_by | Pins that a task file under .tasks/completed/ carries horizon: null whichever branch archived it. Two branches move a task there and their entry conditions are exact complements, so the null-ing written at the first site (T-2163, widened T-2300 after eight CTL-030 instances) could never reach the partial-complete recheck branch. The sharp end is fw task archive-eligible, which re-invokes --status work-completed and therefore drives exclusively through the branch that was unfixed. Every leg asserts WHICH branch ran before asserting the outcome, because the obvious fixture leaves status started-work and never enters the recheck branch at all — a rig that checks only the outcome goes green against the wrong path. A control pins the deliberate case the fix must NOT break: a partial-complete that stays in active/ keeps its stored horizon, which is why the post-condition keys on location, not status. The mutation control removes the post-condition from a live-derived copy and needs a symlink farm, since update-task.sh derives FRAMEWORK_ROOT from its own location and a dead subject reads exactly like a regressed one. Reported by peer 832-Workflow-designer (their T-654 BUG 1); confirmed in-tree first. |
| [t3219_verification_count_reconciliation](/docs/generated/tests-unit-t3219_verification_count_reconciliation) | tests_by | Pins the P-011 verification gate against unreconciled counts: a stdin-reading verification command must not swallow the rest of the block, and pass+fail must equal total or the close is refused. Runs mutated copies of update-task.sh from a symlink farm because FRAMEWORK_ROOT is derived from script location. |
| [t3220_verification_gate_exits](/docs/generated/tests-unit-t3220_verification_gate_exits) | tests_by | Pins that every failure path in run_verification_commands exits rather than returns, and that the choice does not depend on set -euo pipefail 1700 lines away. Four measured cells (exit/return x errexit present/absent) isolate the dependency; the two control cells stop the suite passing against anything. |
| [t3235_archived_horizon_invariant](/docs/generated/tests-unit-t3235_archived_horizon_invariant) | called_by | Pins that a task file under .tasks/completed/ carries horizon: null whichever branch archived it. Two branches move a task there and their entry conditions are exact complements, so the null-ing written at the first site (T-2163, widened T-2300 after eight CTL-030 instances) could never reach the partial-complete recheck branch. The sharp end is fw task archive-eligible, which re-invokes --status work-completed and therefore drives exclusively through the branch that was unfixed. Every leg asserts WHICH branch ran before asserting the outcome, because the obvious fixture leaves status started-work and never enters the recheck branch at all — a rig that checks only the outcome goes green against the wrong path. A control pins the deliberate case the fix must NOT break: a partial-complete that stays in active/ keeps its stored horizon, which is why the post-condition keys on location, not status. The mutation control removes the post-condition from a live-derived copy and needs a symlink farm, since update-task.sh derives FRAMEWORK_ROOT from its own location and a dead subject reads exactly like a regressed one. Reported by peer 832-Workflow-designer (their T-654 BUG 1); confirmed in-tree first. |
| [audit-yaml-validator](/docs/generated/audit-yaml-validator) | called_by | Validate all project YAML files parse correctly. Part of the audit structure section. Added as regression test after T-206 silent corruption. |
| [human_review_state](/docs/generated/lib-human_review_state) | called_by | Classifies a task file's '### Human' AC blocks for the P-013 render gate (prints has_review/only_other/empty/no_section/error); single source of truth extracted from update-task.sh (T-3288) |

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
