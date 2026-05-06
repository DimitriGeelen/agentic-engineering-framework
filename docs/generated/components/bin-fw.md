# fw

> Single entry point for all framework operations. Reads .framework.yaml from the project directory to resolve FRAMEWORK_ROOT, then routes commands to the appropriate agent. Supports both in-repo and shared tooling modes.

**Type:** script | **Subsystem:** framework-core | **Location:** `bin/fw`

## What It Does

fw - Agentic Engineering Framework CLI
Single entry point for all framework operations.
Reads .framework.yaml from the project directory to resolve
FRAMEWORK_ROOT, then routes commands to the appropriate agent.
When run from a project that uses the framework as shared tooling,
fw reads .framework.yaml to find the framework install path.
When run from inside the framework repo itself, it auto-detects.

### Framework Reference

`fw` is the single entry point for all framework operations — it resolves paths, sets env vars, and routes to agents. Discover commands via `fw help`, `fw <cmd> --help`, or the Quick Reference section below.

**Path resolution:** `fw` finds the framework via `bin/fw`'s location (inside framework repo) or via `.framework.yaml` in the project root (shared tooling mode).

*(truncated — see CLAUDE.md for full section)*

## Dependencies (43)

| Target | Relationship |
|--------|-------------|
| `agents/task-create/create-task.sh` | calls |
| `agents/task-create/update-task.sh` | calls |
| `C-004` | calls |
| `agents/audit/plugin-audit.sh` | calls |
| `C-001` | calls |
| `agents/fabric/fabric.sh` | calls |
| `agents/git/git.sh` | calls |
| `agents/handover/handover.sh` | calls |
| `agents/healing/healing.sh` | calls |
| `agents/resume/resume.sh` | calls |
| `agents/mcp/mcp-reaper.sh` | calls |
| `agents/observe/observe.sh` | calls |
| `lib/inception.sh` | calls |
| `lib/promote.sh` | calls |
| `lib/assumption.sh` | calls |
| `lib/bus.sh` | calls |
| `lib/init.sh` | calls |
| `lib/upgrade.sh` | calls |
| `lib/setup.sh` | calls |
| `lib/harvest.sh` | calls |
| `web/app.py` | calls |
| `agents/audit/self-audit.sh` | calls |
| `agents/onboarding-test/test-onboarding.sh` | calls |
| `agents/docgen/generate-article.sh` | calls |
| `agents/docgen/generate-component.sh` | calls |
| `agents/termlink/termlink.sh` | calls |
| `lib/compat.sh` | calls |
| `lib/review.sh` | calls |
| `lib/ask.sh` | calls |
| `lib/tasks.sh` | calls |
| `lib/dispatch.sh` | calls |
| `lib/upstream.sh` | calls |
| `lib/preflight.sh` | calls |
| `lib/validate-init.sh` | calls |
| `lib/update.sh` | calls |
| `bin/watchtower.sh` | calls |
| `lib/build.sh` | calls |
| `lib/pickup.sh` | calls |
| `lib/colors.sh` | calls |
| `lib/costs.sh` | calls |
| `lib/config.sh` | calls |
| `lib/task-audit.sh` | calls |
| `lib/watchtower.sh` | calls |

## Used By (180)

| Component | Relationship |
|-----------|-------------|
| `agents/audit/self-audit.sh` | read_by |
| `lib/upstream.sh` | called_by |
| `web/subprocess_utils.py` | called_by |
| `tests/integration/fw_work_on.bats` | called-by |
| `tests/integration/fw_init.bats` | called-by |
| `tests/integration/fw_handover.bats` | called-by |
| `tests/integration/fw_decisions.bats` | called-by |
| `tests/integration/fw_learnings.bats` | called-by |
| `tests/integration/fw_help.bats` | called-by |
| `tests/integration/fw_preflight.bats` | called-by |
| `bin/fw-shim` | called-by |
| `tests/integration/fw_fabric.bats` | called-by |
| `tests/integration/fw_vendor.bats` | called-by |
| `tests/integration/fw_approvals.bats` | called-by |
| `tests/integration/fw_version.bats` | called-by |
| `tests/integration/fw_resume.bats` | called-by |
| `tests/integration/fw_cron.bats` | called-by |
| `tests/integration/fw_inception.bats` | called-by |
| `tests/integration/fw_gaps.bats` | called-by |
| `tests/integration/fw_assumption.bats` | called-by |
| `tests/integration/fw_metrics.bats` | called-by |
| `tests/integration/fw_promote.bats` | called-by |
| `tests/integration/fw_audit.bats` | called-by |
| `tests/integration/fw_git.bats` | called-by |
| `tests/integration/fw_bus.bats` | called-by |
| `tests/integration/fw_healing.bats` | called-by |
| `tests/integration/fw_fix_learned.bats` | called-by |
| `tests/integration/fw_notify.bats` | called-by |
| `tests/integration/fw_task.bats` | called-by |
| `tests/integration/fw_patterns.bats` | called-by |
| `tests/integration/fw_search.bats` | called-by |
| `tests/integration/fw_practices.bats` | called-by |
| `tests/integration/fw_validate_init.bats` | called-by |
| `tests/integration/fw_upstream.bats` | called-by |
| `tests/integration/fw_harvest.bats` | called-by |
| `tests/integration/fw_tier0.bats` | called-by |
| `tests/integration/fw_doctor.bats` | called-by |
| `tests/integration/fw_timeline.bats` | called-by |
| `tests/integration/fw_context.bats` | called-by |
| `tests/integration/fw_onboarding.bats` | called-by |
| `tests/integration/fw_hook.bats` | called-by |
| `tests/integration/fw_traceability.bats` | called-by |
| `tests/integration/fw_costs.bats` | tested_by |
| `tests/integration/fw_self_test.bats` | tested_by |
| `tests/integration/fw_config.bats` | tested_by |
| `bin/fw-shim` | called_by |
| `tests/integration/fw_approvals.bats` | called_by |
| `tests/integration/fw_assumption.bats` | called_by |
| `tests/integration/fw_audit.bats` | called_by |
| `tests/integration/fw_bus.bats` | called_by |
| `tests/integration/fw_config.bats` | called_by |
| `tests/integration/fw_context.bats` | called_by |
| `tests/integration/fw_costs.bats` | called_by |
| `tests/integration/fw_cron.bats` | called_by |
| `tests/integration/fw_decisions.bats` | called_by |
| `tests/integration/fw_doctor.bats` | called_by |
| `tests/integration/fw_fabric.bats` | called_by |
| `tests/integration/fw_fix_learned.bats` | called_by |
| `tests/integration/fw_gaps.bats` | called_by |
| `tests/integration/fw_git.bats` | called_by |
| `tests/integration/fw_handover.bats` | called_by |
| `tests/integration/fw_harvest.bats` | called_by |
| `tests/integration/fw_healing.bats` | called_by |
| `tests/integration/fw_help.bats` | called_by |
| `tests/integration/fw_hook.bats` | called_by |
| `tests/integration/fw_inception.bats` | called_by |
| `tests/integration/fw_init.bats` | called_by |
| `tests/integration/fw_learnings.bats` | called_by |
| `tests/integration/fw_metrics.bats` | called_by |
| `tests/integration/fw_notify.bats` | called_by |
| `tests/integration/fw_onboarding.bats` | called_by |
| `tests/integration/fw_patterns.bats` | called_by |
| `tests/integration/fw_practices.bats` | called_by |
| `tests/integration/fw_preflight.bats` | called_by |
| `tests/integration/fw_promote.bats` | called_by |
| `tests/integration/fw_resume.bats` | called_by |
| `tests/integration/fw_search.bats` | called_by |
| `tests/integration/fw_self_test.bats` | called_by |
| `tests/integration/fw_task.bats` | called_by |
| `tests/integration/fw_tier0.bats` | called_by |
| `tests/integration/fw_timeline.bats` | called_by |
| `tests/integration/fw_traceability.bats` | called_by |
| `tests/integration/fw_upstream.bats` | called_by |
| `tests/integration/fw_validate_init.bats` | called_by |
| `tests/integration/fw_vendor.bats` | called_by |
| `tests/integration/fw_version.bats` | called_by |
| `tests/integration/fw_work_on.bats` | called_by |
| `lib/release.sh` | called_by_by |
| `agents/context/pl007-scanner.sh` | called_by |
| `agents/context/subagent-stop.sh` | called_by |
| `tests/unit/task_reid.bats` | called_by |
| `tests/governance/test_pretooluse_gates.bats` | tests_by |
| `tests/governance/test_task_lifecycle_gates.bats` | tests_by |
| `tests/integration/audit_blocks_review_and_decide.bats` | tests_by |
| `tests/integration/cron_install.bats` | tests_by |
| `tests/integration/fw_approvals.bats` | tests_by |
| `tests/integration/fw_assumption.bats` | tests_by |
| `tests/integration/fw_audit.bats` | tests_by |
| `tests/integration/fw_bus.bats` | tests_by |
| `tests/integration/fw_config.bats` | tests_by |
| `tests/integration/fw_context.bats` | tests_by |
| `tests/integration/fw_costs.bats` | tests_by |
| `tests/integration/fw_cron.bats` | tests_by |
| `tests/integration/fw_decisions.bats` | tests_by |
| `tests/integration/fw_doctor.bats` | tests_by |
| `tests/integration/fw_fabric.bats` | tests_by |
| `tests/integration/fw_fix_learned.bats` | tests_by |
| `tests/integration/fw_gaps.bats` | tests_by |
| `tests/integration/fw_git.bats` | tests_by |
| `tests/integration/fw_handover.bats` | tests_by |
| `tests/integration/fw_harvest.bats` | tests_by |
| `tests/integration/fw_healing.bats` | tests_by |
| `tests/integration/fw_help.bats` | tests_by |
| `tests/integration/fw_hook.bats` | tests_by |
| `tests/integration/fw_inception.bats` | tests_by |
| `tests/integration/fw_init.bats` | tests_by |
| `tests/integration/fw_learnings.bats` | tests_by |
| `tests/integration/fw_metrics.bats` | tests_by |
| `tests/integration/fw_notify.bats` | tests_by |
| `tests/integration/fw_onboarding.bats` | tests_by |
| `tests/integration/fw_patterns.bats` | tests_by |
| `tests/integration/fw_pickup.bats` | tests_by |
| `tests/integration/fw_practices.bats` | tests_by |
| `tests/integration/fw_preflight.bats` | tests_by |
| `tests/integration/fw_promote.bats` | tests_by |
| `tests/integration/fw_resume.bats` | tests_by |
| `tests/integration/fw_search.bats` | tests_by |
| `tests/integration/fw_self_test.bats` | tests_by |
| `tests/integration/fw_task.bats` | tests_by |
| `tests/integration/fw_tier0.bats` | tests_by |
| `tests/integration/fw_timeline.bats` | tests_by |
| `tests/integration/fw_traceability.bats` | tests_by |
| `tests/integration/fw_upstream.bats` | tests_by |
| `tests/integration/fw_validate_init.bats` | tests_by |
| `tests/integration/fw_vendor.bats` | tests_by |
| `tests/integration/fw_version.bats` | tests_by |
| `tests/integration/fw_work_on.bats` | tests_by |
| `tests/unit/add_learning_id_allocator.bats` | tests_by |
| `tests/unit/audit_task_tools.bats` | tests_by |
| `tests/unit/block_task_tools.bats` | tests_by |
| `tests/unit/context_safe_commands.bats` | tests_by |
| `tests/unit/cron_flock_parity.bats` | tests_by |
| `tests/unit/doctor_duplicate_hook_detection.bats` | tests_by |
| `tests/unit/doctor_hook_exercise.bats` | tests_by |
| `tests/unit/escalation_scan_v05.bats` | tests_by |
| `tests/unit/focus_drift_gate.bats` | tests_by |
| `tests/unit/hook_absolute_paths.bats` | tests_by |
| `tests/unit/hook_enable_absolute_path.bats` | tests_by |
| `tests/unit/hook_telemetry.bats` | tests_by |
| `tests/unit/pickup_type_routing.bats` | tests_by |
| `tests/unit/session_start_hook_warning.bats` | tests_by |
| `tests/unit/task_reid.bats` | tests_by |
| `tests/unit/test_boundary_hook_arguments.bats` | tests_by |
| `tests/unit/test_doctor_litellm_ollama.bats` | tests_by |
| `tests/unit/test_doctor_scope_tags.bats` | tests_by |
| `tests/unit/test_fw_gaps_closure_check.bats` | tests_by |
| `tests/unit/test_orchestrator_status_synthetic_filter.bats` | tests_by |
| `tests/unit/test_worker_kind_drift.bats` | tests_by |
| `tests/unit/upgrade_dedupe_user_hooks.bats` | tests_by |
| `tests/unit/upgrade_duplicate_hook_detection.bats` | tests_by |
| `tests/unit/verify_acs.bats` | tests_by |
| `lib/doctor-hook-exercise.py` | called_by |
| `lib/hook-threshold.py` | called_by |
| `lib/resolver.py` | called_by |
| `tests/playwright/test_api_fabric_source.py` | called_by |
| `tests/playwright/test_file_viewer.py` | called_by |
| `tests/unit/test_arc_system.py` | called_by |
| `tests/unit/test_audit_arc_completion.py` | called_by |
| `tests/unit/test_enrich_bats_parser.py` | called_by |
| `tests/unit/test_fabric_drift_absolute_paths.py` | called_by |
| `tests/unit/test_fabric_drift_performance.py` | called_by |
| `tests/unit/test_orchestrator_outcome_dedup.py` | called_by |
| `tests/unit/test_orchestrator_status_outcomes.py` | called_by |
| `web/blueprints/approvals.py` | called_by |
| `web/blueprints/cron.py` | called_by |
| `web/shared.py` | called_by |
| `lib/reviewer/classifier.py` | called_by |
| `lib/reviewer/drift.py` | called_by |
| `lib/reviewer/static_scan.py` | called_by |

## Documentation

- [Deep Dive: Tier 0 Protection](docs/articles/deep-dives/02-tier0-protection.md) (deep-dive)
- [Deep Dive: The Authority Model](docs/articles/deep-dives/06-authority-model.md) (deep-dive)

## Related

### Tasks
- T-874: Sync vendored bin/fw with T-873 approvals fix
- T-889: fw config set/get — read and write persistent settings in .framework.yaml
- T-890: Add fw config to help output and CLAUDE.md quick reference
- T-898: Fix _derive_version — use framework git repo, not cwd
- T-969: Playwright test infrastructure — tests/playwright/ + fw test playwright + conftest.py (T-968 Phase 1)

---
*Auto-generated from Component Fabric. Card: `bin-fw.yaml`*
*Last verified: 2026-02-20*
